import 'package:meta/meta.dart';

import 'unknown_renderer.dart'
    if (dart.library.js_interop) 'web_renderer.dart'
    if (dart.library.io) 'io_renderer.dart' as implementation;

@internal
class RendererWrapper {
  late final FlutterRenderer? renderer = implementation.getRenderer();
}

enum FlutterRenderer {
  /// https://skia.org/
  skia,

  /// https://docs.flutter.dev/perf/impeller
  impeller,

  /// https://docs.flutter.dev/platform-integration/web/renderers#canvaskit
  canvasKit,

  /// https://docs.flutter.dev/platform-integration/web/renderers#skwasm
  skwasm,

  /// HTML is still there but considered legacy
  html,
  unknown,
}
