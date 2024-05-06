import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import '../../sentry_flutter.dart';

@internal
class WidgetFilter {
  static const _defaultColor = Color.fromARGB(255, 0, 0, 0);
  final bool redactText;
  final bool redactImages;
  late double _pixelRatio;
  late Rect _bounds;
  final List<WidgetFilterItem> items = [];
  final SentryLogger logger;

  WidgetFilter(
      {required this.redactText,
      required this.redactImages,
      required this.logger});

  void setupAndClear(double pixelRatio, Rect bounds) {
    _pixelRatio = pixelRatio;
    _bounds = bounds;
    items.clear();
  }

  void obscure(Element element) {
    final widget = element.widget;

    if (!_isVisible(widget)) {
      _devlog("WidgetFilter skipping invisible: $widget");
      return;
    }

    final obscured = _obscureIfNeeded(element, widget);
    if (!obscured) {
      element.visitChildElements(obscure);
    }
  }

  @pragma('vm:prefer-inline')
  bool _obscureIfNeeded(Element element, Widget widget) {
    Color? color;

    if (redactText && widget is Text) {
      color = widget.style?.color;
    } else if (redactText && widget is EditableText) {
      color = widget.style.color;
    } else if (redactImages && widget is Image) {
      color = widget.color;
    } else {
      // No other type is currently obscured.
      return false;
    }

    final renderObject = element.renderObject;
    if (renderObject is! RenderBox) {
      _devlog(
          "WidgetFilter cannot obscure widget $widget, it's renderObject is not a RenderBox");
      return false;
    }

    final size = element.size;
    if (size == null) {
      _devlog(
          "WidgetFilter cannot obscure widget $widget, it's renderObject has a null size");
      return false;
    }

    final offset = renderObject.localToGlobal(Offset.zero);

    final rect = Rect.fromLTWH(
      offset.dx * _pixelRatio,
      offset.dy * _pixelRatio,
      size.width * _pixelRatio,
      size.height * _pixelRatio,
    );

    if (!rect.overlaps(_bounds)) {
      _devlog("WidgetFilter skipping offscreen: $widget");
      return false;
    }

    items.add(WidgetFilterItem(color ?? _defaultColor, rect));
    _devlog("WidgetFilter obscuring: $widget");

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

  // Should be completely trimmed out in production builds.
  @pragma('vm:prefer-inline')
  void _devlog(String message) {
    assert(() {
      logger(SentryLevel.debug, message);
      return true;
    }());
  }
}

class WidgetFilterItem {
  final Color color;
  final Rect bounds;

  const WidgetFilterItem(this.color, this.bounds);
}
