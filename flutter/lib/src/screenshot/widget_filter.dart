import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../sentry_asset_bundle.dart';
import 'masking_config.dart';

@internal
class WidgetFilter {
  final items = <WidgetFilterItem>[];
  final SdkLogger logger;
  final SentryMaskingConfig config;
  late WidgetFilterColorScheme _scheme;
  late RenderObject _root;
  late Rect _bounds;
  late List<Element> _visitList;
  final _warnedWidgets = <int>{};

  /// Used to test _obscureElementOrParent
  @visibleForTesting
  bool throwInObscure = false;

  WidgetFilter(this.config, this.logger);

  void obscure({
    required RenderRepaintBoundary root,
    required BuildContext context,
    required WidgetFilterColorScheme colorScheme,
    Rect? bounds,
  }) {
    _root = root;
    _scheme = colorScheme;
    _bounds = bounds ?? Offset.zero & root.size;
    assert(colorScheme.background.isOpaque);
    assert(colorScheme.defaultMask.isOpaque);
    assert(colorScheme.defaultTextMask.isOpaque);

    // clear the output list
    items.clear();

    // Reset the list of elements we're going to process.
    // Then do a breadth-first tree traversal on all the widgets.
    // TODO benchmark performance compared to to DoubleLinkedQueue.
    _visitList = [];
    context.visitChildElements(_visitList.add);
    while (_visitList.isNotEmpty) {
      // Get a handle on the items we're supposed to process in this step.
      // Then _visitList (which is updated in _process()) with a new instance.
      final currentList = _visitList;
      _visitList = [];

      for (final element in currentList) {
        _process(element);
      }
    }
  }

  void _process(Element element) {
    final widget = element.widget;

    if (!_isVisible(widget)) {
      assert(() {
        logger(SentryLevel.debug, "WidgetFilter skipping invisible: $widget");
        return true;
      }());
      return;
    }

    final decision = config.shouldMask(element, widget);
    switch (decision) {
      case SentryMaskingDecision.mask:
        final item = _obscureElementOrParent(element, widget);
        if (item != null) {
          items.add(item);
        }
        break;
      case SentryMaskingDecision.unmask:
        logger(SentryLevel.debug, "WidgetFilter unmasked: $widget");
        break;
      case SentryMaskingDecision.continueProcessing:
        // If this element should not be obscured, visit and check its children.
        element.debugVisitOnstageChildren(_visitList.add);
        break;
    }
  }

  /// Determine the color and bounding box of the widget.
  /// If the widget is offscreen, returns null.
  /// If the widget cannot be obscured, obscures the parent.
  @pragma('vm:prefer-inline')
  WidgetFilterItem? _obscureElementOrParent(Element element, Widget widget) {
    while (true) {
      try {
        return _obscure(element, widget);
      } catch (e, stackTrace) {
        final parent = element.parent;
        if (!_warnedWidgets.contains(widget.hashCode)) {
          _warnedWidgets.add(widget.hashCode);
          logger(
              SentryLevel.warning,
              'WidgetFilter cannot mask widget $widget: $e.'
              'Obscuring the parent instead: ${parent?.widget}.',
              stackTrace: stackTrace);
        }
        if (parent == null) {
          return WidgetFilterItem(_scheme.defaultMask, _bounds);
        }
        element = parent;
        widget = element.widget;
      }
    }
  }

  /// Determine the color and bounding box of the widget.
  /// If the widget is offscreen, returns null.
  /// This function may throw in which case the caller is responsible for
  /// calling it again on the parent element.
  @pragma('vm:prefer-inline')
  WidgetFilterItem? _obscure(Element element, Widget widget) {
    final RenderBox renderBox = element.renderObject as RenderBox;
    var rect = _boundingBox(renderBox);

    // If it's a clipped render object, use parent's offset and size.
    // This helps with text fields which often have oversized render objects.
    if (renderBox.parent is RenderStack) {
      final renderStack = (renderBox.parent as RenderStack);
      final clipBehavior = renderStack.clipBehavior;
      if (clipBehavior == Clip.hardEdge ||
          clipBehavior == Clip.antiAlias ||
          clipBehavior == Clip.antiAliasWithSaveLayer) {
        final clipRect = _boundingBox(renderStack);
        rect = rect.intersect(clipRect);
      }
    }

    if (!rect.overlaps(_bounds)) {
      assert(() {
        logger(SentryLevel.debug, "WidgetFilter skipping offscreen: $widget");
        return true;
      }());
      return null;
    }

    assert(() {
      logger(SentryLevel.debug, "WidgetFilter masking: $widget");
      return true;
    }());

    Color? color;
    if (widget is Text) {
      color = widget.style?.color;
      if (color == null && renderBox is RenderParagraph) {
        color = renderBox.text.style?.color;
      }
      color ??= _scheme.defaultTextMask;
    } else if (widget is EditableText) {
      color = widget.style.color ?? _scheme.defaultTextMask;
    } else if (widget is Image) {
      color = widget.color;
    }

    // We need to make the color non-transparent or the mask would
    // also be partially transparent.
    if (color == null) {
      color = _scheme.defaultMask;
    } else if (!color.isOpaque) {
      color = Color.alphaBlend(color, _scheme.background);
    }

    // test-only code
    assert(() {
      if (throwInObscure) {
        throwInObscure = false;
        return false;
      }
      return true;
    }());

    assert(color.isOpaque, 'Mask color must be opaque: $color');
    return WidgetFilterItem(color, rect);
  }

  // We cut off some widgets early because they're not visible at all.
  @pragma('vm:prefer-inline')
  bool _isVisible(Widget widget) {
    if (widget is Visibility) {
      return widget.visible;
    }
    if (widget is Opacity) {
      return widget.opacity > 0;
    }
    if (widget is Offstage) {
      return !widget.offstage;
    }
    return true;
  }

  @internal
  @pragma('vm:prefer-inline')
  static bool isBuiltInAssetImage(
      AssetBundleImageProvider image, AssetBundle rootAssetBundle) {
    late final AssetBundle? bundle;
    if (image is AssetImage) {
      bundle = image.bundle;
    } else if (image is ExactAssetImage) {
      bundle = image.bundle;
    } else {
      return false;
    }
    return (bundle == null ||
        bundle == rootAssetBundle ||
        (bundle is SentryAssetBundle && bundle.bundle == rootAssetBundle));
  }

  @pragma('vm:prefer-inline')
  Rect _boundingBox(RenderBox box) {
    final transform = box.getTransformTo(_root);
    return MatrixUtils.transformRect(transform, box.paintBounds);
  }
}

@internal
class WidgetFilterItem {
  final Color color;
  final Rect bounds;

  const WidgetFilterItem(this.color, this.bounds);
}

extension on Element {
  Element? get parent {
    Element? result;
    visitAncestorElements((el) {
      result = el;
      return false;
    });
    return result;
  }
}

@internal
extension Opaqueness on Color {
  @pragma('vm:prefer-inline')
  // ignore: deprecated_member_use
  bool get isOpaque => alpha == 0xff;

  @pragma('vm:prefer-inline')
  // ignore: deprecated_member_use
  Color asOpaque() => isOpaque ? this : Color.fromARGB(0xff, red, green, blue);
}

@internal
class WidgetFilterColorScheme {
  final Color defaultMask;
  final Color defaultTextMask;
  final Color background;

  const WidgetFilterColorScheme(
      {required this.defaultMask,
      required this.defaultTextMask,
      required this.background});
}
