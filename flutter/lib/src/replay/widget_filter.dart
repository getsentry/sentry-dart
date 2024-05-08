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
  final Set<Widget> _warnedWidgets = {};

  WidgetFilter(
      {required this.redactText,
      required this.redactImages,
      required this.logger});

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
      _cantObscure(widget, "it's renderObject is not a RenderBox");
      return false;
    }

    final size = element.size;
    if (size == null) {
      _cantObscure(widget, "it's renderObject has a null size");
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

  @pragma('vm:prefer-inline')
  void _cantObscure(Widget widget, String message) {
    if (!_warnedWidgets.contains(widget)) {
      _warnedWidgets.add(widget);
      logger(SentryLevel.warning,
          "WidgetFilter cannot obscure widget $widget: $message");
    }
  }
}

class WidgetFilterItem {
  final Color color;
  final Rect bounds;

  const WidgetFilterItem(this.color, this.bounds);
}
