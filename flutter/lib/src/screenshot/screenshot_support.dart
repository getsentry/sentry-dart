import '../../sentry_flutter.dart';
import '../renderer/renderer.dart';

/// Returns `true` if capturing screenshots are allowed in the current environment.
///
/// - On mobile / desktop we allow them unconditionally.
/// - On Web we allow them only when the renderer is CanvasKit or Skwasm.
bool isScreenshotSupported(SentryFlutterOptions options) {
  if (!options.platform.isWeb) {
    return true;
  }

  const supportedWebRenderers = {
    FlutterRenderer.canvasKit,
    FlutterRenderer.skwasm,
  };

  return supportedWebRenderers.contains(options.rendererWrapper.renderer);
}
