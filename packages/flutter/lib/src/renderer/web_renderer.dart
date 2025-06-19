import 'dart:js_interop';

import 'renderer.dart';

FlutterRenderer? getRenderer() {
  return isCanvasKitRenderer ? FlutterRenderer.canvasKit : FlutterRenderer.html;
}

bool get isCanvasKitRenderer {
  return _windowFlutterCanvasKit != null;
}

// These values are set by the engine. They are used to determine if the
// application is using canvaskit or skwasm.
//
// See https://github.com/flutter/flutter/blob/414d9238720a3cde85475f49ce0ba313f95046f7/packages/flutter/lib/src/foundation/_capabilities_web.dart#L10
@JS('window.flutterCanvasKit')
external JSAny? get _windowFlutterCanvasKit;
