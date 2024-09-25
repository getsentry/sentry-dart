import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../sentry_asset_bundle.dart';

@internal
class WidgetFilter {
  final items = <WidgetFilterItem>[];
  final SentryLogger logger;
  final Map<Type, WidgetFilterMaskingConfig> config;
  static const _defaultColor = Color.fromARGB(255, 0, 0, 0);
  late double _pixelRatio;
  late Rect _bounds;
  final _warnedWidgets = <int>{};

  WidgetFilter(this.config, this.logger);

  void obscure(BuildContext context, double pixelRatio, Rect bounds) {
    _pixelRatio = pixelRatio;
    _bounds = bounds;
    items.clear();
    if (context is Element) {
      _obscure(context);
    } else {
      context.visitChildElements(_obscure);
    }
  }

  void _obscure(Element element) {
    final widget = element.widget;

    if (!_isVisible(widget)) {
      assert(() {
        logger(SentryLevel.debug, "WidgetFilter skipping invisible: $widget");
        return true;
      }());
      return;
    }

    final obscured = _obscureIfNeeded(element, widget);
    if (!obscured) {
      element.visitChildElements(_obscure);
    }
  }

  @pragma('vm:prefer-inline')
  bool _obscureIfNeeded(Element element, Widget widget) {
    final maskingConfig = config[widget.runtimeType];
    if (maskingConfig == null) {
      return false;
    } else if (!maskingConfig.shouldMask(element, widget)) {
      logger(SentryLevel.debug, "WidgetFilter skipping: $widget");
      return false;
    }

    Color? color;
    if (widget is Text) {
      color = widget.style?.color;
    } else if (widget is EditableText) {
      color = widget.style.color;
    } else if (widget is Image) {
      color = widget.color;
    } else {
      // No other type is currently obscured.
      return false;
    }

    final renderObject = element.renderObject;
    if (renderObject is! RenderBox) {
      _cantObscure(widget, "its renderObject is not a RenderBox");
      return false;
    }

    var rect = _boundingBox(renderObject);

    // If it's a clipped render object, use parent's offset and size.
    // This helps with text fields which often have oversized render objects.
    if (renderObject.parent is RenderStack) {
      final renderStack = (renderObject.parent as RenderStack);
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
      return false;
    }

    items.add(WidgetFilterItem(color ?? _defaultColor, rect));
    assert(() {
      logger(SentryLevel.debug, "WidgetFilter obscuring: $widget");
      return true;
    }());

    return true;
  }

  // We cut off some widgets early because they're not visible at all.
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
  void _cantObscure(Widget widget, String message) {
    if (!_warnedWidgets.contains(widget.hashCode)) {
      _warnedWidgets.add(widget.hashCode);
      logger(SentryLevel.warning,
          "WidgetFilter cannot obscure widget $widget: $message");
    }
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

@internal
class WidgetFilterMaskingConfig {
  static const mask = WidgetFilterMaskingConfig._(1, 'mask');
  static const show = WidgetFilterMaskingConfig._(2, 'mask');

  final int index;
  final String _name;
  final bool Function(Element, Widget)? _shouldMask;

  const WidgetFilterMaskingConfig._(this.index, this._name)
      : _shouldMask = null;
  const WidgetFilterMaskingConfig.custom(this._shouldMask)
      : index = 3,
        _name = 'custom';

  @override
  String toString() => "$WidgetFilterMaskingConfig.$_name";

  bool shouldMask(Element element, Widget widget) {
    switch (this) {
      case mask:
        return true;
      case show:
        return false;
      default:
        return _shouldMask!(element, widget);
    }
  }
}
