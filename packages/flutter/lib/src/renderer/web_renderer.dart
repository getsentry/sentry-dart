import 'package:flutter/foundation.dart';

import 'renderer.dart';

FlutterRenderer? getRenderer() {
  if (isCanvasKit) return FlutterRenderer.canvasKit;
  if (isSkwasm) return FlutterRenderer.skwasm;
  return FlutterRenderer.html;
}
