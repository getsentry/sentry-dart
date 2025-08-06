import '../../sentry_flutter.dart';
import '../renderer/renderer.dart';

extension ScreenshotSupport on SentryFlutterOptions {
  /// Returns `true` if capturing screenshots are allowed in the current environment.
  ///
  /// - On mobile / desktop we allow them unconditionally.
  /// - On Web we allow them only when the renderer is CanvasKit or Skwasm.
  bool get isScreenshotSupported {
    // Mobile / desktop → always OK.
    if (!platform.isWeb) return true;

    const supportedWebRenderers = {
      FlutterRenderer.canvasKit,
      FlutterRenderer.skwasm,
    };
    return supportedWebRenderers.contains(rendererWrapper.renderer);
  }
}
