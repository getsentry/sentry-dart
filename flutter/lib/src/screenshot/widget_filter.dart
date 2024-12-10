import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../sentry_asset_bundle.dart';
import 'masking_config.dart';

@internal
class WidgetFilter {
  final items = <WidgetFilterItem>[];
  final SentryLogger logger;
  final SentryMaskingConfig config;
  late WidgetFilterColorScheme _scheme;
  late double _pixelRatio;
  late Rect _bounds;
  final _warnedWidgets = <int>{};

  /// Used to test _obscureElementOrParent
  @visibleForTesting
  bool throwInObscure = false;

  WidgetFilter(this.config, this.logger);

  void obscure({
    required BuildContext context,
    required double pixelRatio,
    required Rect bounds,
    required WidgetFilterColorScheme colorScheme,
  }) {
    _pixelRatio = pixelRatio;
    _bounds = bounds;
    _scheme = colorScheme;
    assert(colorScheme.background.isOpaque);
    assert(colorScheme.defaultMask.isOpaque);
    assert(colorScheme.defaultTextMask.isOpaque);
    items.clear();
    if (context is Element) {
      _process(context);
    } else {
      context.visitChildElements(_process);
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
        element.visitChildElements(_process);
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
      assert(color.isOpaque, 'Mask color must be opaque: $color');
    }

    // test-only code
    assert(() {
      if (throwInObscure) {
        throwInObscure = false;
        return false;
      }
      return true;
    }());

    assert(color.isOpaque);
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
    final offset = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      offset.dx * _pixelRatio,
      offset.dy * _pixelRatio,
      box.size.width * _pixelRatio,
      box.size.height * _pixelRatio,
    );
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
  bool get isOpaque => alpha == 0xff;

  @pragma('vm:prefer-inline')
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
