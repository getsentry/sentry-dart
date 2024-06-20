import 'package:meta/meta.dart';

import 'unknown_renderer.dart'
    if (dart.library.html) 'html_renderer.dart'
    if (dart.library.js_interop) 'web_renderer.dart'
    if (dart.library.io) 'io_renderer.dart' as implementation;

@internal
class RendererWrapper {
  FlutterRenderer? getRenderer() {
    return implementation.getRenderer();
  }
}

enum FlutterRenderer {
  /// https://skia.org/
  skia,

  /// https://docs.flutter.dev/perf/impeller
  impeller,

  /// https://docs.flutter.dev/platform-integration/web/renderers
  canvasKit,

  /// https://docs.flutter.dev/platform-integration/web/renderers
  html,
  unknown,
}
