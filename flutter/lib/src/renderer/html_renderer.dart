import 'dart:js' as js;

import 'renderer.dart';

FlutterRenderer getRenderer() {
  return isCanvasKitRenderer ? FlutterRenderer.canvasKit : FlutterRenderer.html;
}

bool get isCanvasKitRenderer {
  final flutterCanvasKit = js.context['flutterCanvasKit'];
  return flutterCanvasKit != null;
}
