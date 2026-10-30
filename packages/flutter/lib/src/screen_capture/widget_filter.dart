import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../assets/sentry_asset_bundle.dart';
import '../utils/internal_logger.dart';
import 'masking_config.dart';

@internal
class WidgetFilter {
  final items = <WidgetFilterItem>[];
  final SentryMaskingConfig config;
  late WidgetFilterColorScheme _scheme;
  late RenderObject _root;
  late Rect _bounds;
  late List<Element> _visitList;
  final _warnedWidgets = <int>{};

  /// Transforms that [SnapshotWidget] painters apply to their child while
  /// painting, keyed by the snapshot's render object. These are invisible to
  /// [RenderObject.getTransformTo], e.g. the scale of [ZoomPageTransitionsBuilder].
  final _paintTransforms = <RenderObject, Matrix4>{};

  /// Whether the last [obscure] found a [SnapshotWidget] showing a snapshot,
  /// i.e. an image of its child taken earlier, like Flutter's zoom page
  /// transition does on native platforms. It is covered with the background,
  /// so [items] can't leak it, but the frame is then of little use.
  bool get hasFrozenSnapshot => _hasFrozenSnapshot;
  var _hasFrozenSnapshot = false;

  /// Used to test _obscureElementOrParent
  @visibleForTesting
  bool throwInObscure = false;

  WidgetFilter(this.config);

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
    _paintTransforms.clear();
    _hasFrozenSnapshot = false;

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
        internalLogger.debug(() => 'WidgetFilter skipping invisible: $widget');
        return true;
      }());
      return;
    }

    // The traversal is breadth-first, so this runs before any descendant
    // is masked.
    if (widget is SnapshotWidget) {
      _recordPaintTransform(element, widget);
      if (widget.controller.allowSnapshotting) {
        // The frame shows an image of the child taken earlier, so where its
        // content is now may not be where it was painted. Cover it, and let
        // the masks of its content, which come later, draw on top.
        _hasFrozenSnapshot = true;
        final item = _obscureSnapshotOrParent(element, widget);
        if (item != null) {
          items.add(item);
        }
      }
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
        assert(() {
          internalLogger.debug(() => 'WidgetFilter unmasked: $widget');
          return true;
        }());
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
  WidgetFilterItem? _obscureElementOrParent(Element element, Widget widget) =>
      _obscureOrParent(element, widget, _obscure);

  /// Covers the area [widget] paints its snapshot to, or its parent if that
  /// fails.
  WidgetFilterItem? _obscureSnapshotOrParent(
    Element element,
    SnapshotWidget widget,
  ) => _obscureOrParent(element, widget, (element, widget) {
    final box = element.renderObject as RenderBox;
    final paintTransform = _paintTransforms[box];
    final rect = paintTransform == null
        ? _boundingBox(box)
        : MatrixUtils.transformRect(
            _transformTo(box).multiplied(paintTransform),
            box.paintBounds,
          );
    return rect.overlaps(_bounds)
        ? WidgetFilterItem(_scheme.background, rect)
        : null;
  });

  @pragma('vm:prefer-inline')
  WidgetFilterItem? _obscureOrParent(
    Element element,
    Widget widget,
    WidgetFilterItem? Function(Element, Widget) obscure,
  ) {
    while (true) {
      try {
        return obscure(element, widget);
      } catch (e, stackTrace) {
        final parent = element.parent;
        if (!_warnedWidgets.contains(widget.hashCode)) {
          _warnedWidgets.add(widget.hashCode);
          internalLogger.warning(
            () =>
                'WidgetFilter cannot mask widget $widget: $e.'
                'Obscuring the parent instead: ${parent?.widget}.',
            stackTrace: stackTrace,
          );
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
        internalLogger.debug(() => 'WidgetFilter skipping offscreen: $widget');
        return true;
      }());
      return null;
    }

    assert(() {
      internalLogger.debug(() => 'WidgetFilter masking: $widget');
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
    AssetBundleImageProvider image,
    AssetBundle rootAssetBundle,
  ) {
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
  Rect _boundingBox(RenderBox box) =>
      MatrixUtils.transformRect(_transformTo(box), box.paintBounds);

  @pragma('vm:prefer-inline')
  Matrix4 _transformTo(RenderBox box) => _paintTransforms.isEmpty
      ? box.getTransformTo(_root)
      : _getTransformWithPaintTransforms(box);

  /// Like [RenderObject.getTransformTo] with [_root], but also applies the
  /// recorded [_paintTransforms] of the ancestors [box] is painted under.
  Matrix4 _getTransformWithPaintTransforms(RenderBox box) {
    RenderObject from = box;
    var transform = Matrix4.identity();
    for (
      var node = box.parent;
      node != null && node != _root;
      node = node.parent
    ) {
      final paintTransform = _paintTransforms[node];
      if (paintTransform != null) {
        transform = paintTransform.multiplied(from.getTransformTo(node))
          ..multiply(transform);
        from = node;
      }
    }
    return from.getTransformTo(_root)..multiply(transform);
  }

  void _recordPaintTransform(Element element, SnapshotWidget widget) {
    final renderObject = element.renderObject;
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return;
    }
    try {
      final transform = _PaintTransformRecorder.record(
        widget.painter,
        renderObject.size,
      );
      if (transform != null && !transform.isIdentity()) {
        _paintTransforms[renderObject] = transform;
      }
    } catch (e, stackTrace) {
      internalLogger.warning(
        () => 'WidgetFilter cannot read the paint transform of $widget: $e',
        stackTrace: stackTrace,
      );
    }
  }
}

/// Runs a [SnapshotPainter] against a throwaway layer to read the transform
/// it paints its child with, which Flutter only applies while painting.
///
/// The painter must not notice: the child is never painted, and every push
/// returns the `oldLayer` it was given, so the painter's layer handles keep
/// the layers they hold for the real frame.
class _PaintTransformRecorder extends PaintingContext {
  _PaintTransformRecorder(ContainerLayer layer, Size size)
    : super(layer, Offset.zero & size);

  Matrix4 _current = Matrix4.identity();
  Matrix4? _childTransform;

  /// Returns the transform [painter] paints its child with, relative to the
  /// snapshot's own box, or null if the child would not be painted.
  static Matrix4? record(SnapshotPainter painter, Size size) {
    final layer = ContainerLayer();
    final recorder = _PaintTransformRecorder(layer, size);
    try {
      painter.paint(recorder, Offset.zero, size, recorder._paintChild);
      return recorder._childTransform;
    } finally {
      recorder.stopRecordingIfNeeded();
      layer.dispose();
    }
  }

  void _paintChild(PaintingContext context, Offset offset) {
    _childTransform ??= _current.clone()
      ..translateByDouble(offset.dx, offset.dy, 0, 1);
  }

  @override
  TransformLayer? pushTransform(
    bool needsCompositing,
    Offset offset,
    Matrix4 transform,
    PaintingContextCallback painter, {
    TransformLayer? oldLayer,
  }) {
    final previous = _current;
    _current = previous.multiplied(
      Matrix4.translationValues(offset.dx, offset.dy, 0)
        ..multiply(transform)
        ..translateByDouble(-offset.dx, -offset.dy, 0, 1),
    );
    try {
      painter(this, offset);
    } finally {
      _current = previous;
    }
    return oldLayer;
  }

  @override
  OpacityLayer pushOpacity(
    Offset offset,
    int alpha,
    PaintingContextCallback painter, {
    OpacityLayer? oldLayer,
  }) {
    painter(this, offset);
    return oldLayer ?? OpacityLayer();
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

  const WidgetFilterColorScheme({
    required this.defaultMask,
    required this.defaultTextMask,
    required this.background,
  });
}
