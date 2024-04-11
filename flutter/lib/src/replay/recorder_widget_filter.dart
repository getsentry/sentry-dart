import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

@internal
class WidgetFilter {
  final double _pixelRatio;
  final List<Rect> bounds = [];

  WidgetFilter(this._pixelRatio);

  void obscure(Element element) {
    final widget = element.widget;

    if (widget is Visibility && !widget.visible) {
      return;
    }
    if (widget is Opacity && widget.opacity <= 0.0) {
      return;
    }

    if (_shouldObscure(widget)) {
      final renderObject = element.renderObject;
      if (renderObject is RenderBox) {
        final offset = renderObject.localToGlobal(Offset.zero);
        final size = element.size;
        if (size != null) {
          bounds.add(Rect.fromLTWH(
            offset.dx * _pixelRatio,
            offset.dy * _pixelRatio,
            size.width * _pixelRatio,
            size.height * _pixelRatio,
          ));
          return;
        }
      } else {
        // TODO fix logging
        print(
            "Cannot obscure widget $widget, it's renderObject is not a RenderBox");
      }
    }

    element.visitChildElements(obscure);
  }

  bool _shouldObscure(Widget widget) =>
      widget is Image || widget is RichText || widget is TextBox;
}
