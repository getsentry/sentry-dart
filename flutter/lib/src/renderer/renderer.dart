import 'package:meta/meta.dart';

import 'unknown_renderer.dart'
    if (dart.library.html) 'html_renderer.dart'
    if (dart.library.io) 'io_renderer.dart' as implementation;

@internal
class RendererWrapper {
  FlutterRenderer getRenderer() {
    return implementation.getRenderer();
  }
}

enum FlutterRenderer {
  skia,
  canvasKit,
  html,
  unknown,
}
