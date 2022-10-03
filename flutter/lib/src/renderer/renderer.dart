import 'unknown_renderer.dart'
    if (dart.library.html) 'html_renderer.dart'
    if (dart.library.io) 'io_renderer.dart' as implementation;

FlutterRenderer getRenderer() => implementation.getRenderer();

String getRendererAsString() {
  switch (getRenderer()) {
    case FlutterRenderer.skia:
      return 'Skia';
    case FlutterRenderer.canvasKit:
      return 'CanvasKit';
    case FlutterRenderer.html:
      return 'HTML';
    case FlutterRenderer.unknown:
      return 'Unknown';
  }
}

enum FlutterRenderer {
  skia,
  canvasKit,
  html,
  unknown,
}
