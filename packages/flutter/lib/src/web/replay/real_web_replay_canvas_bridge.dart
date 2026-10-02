import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:meta/meta.dart';
import 'package:web/web.dart' as web;

import 'web_replay_canvas_bridge.dart';

/// The subset of the JS SDK's `replayCanvasIntegration()` return value this
/// bridge needs. The integration itself is constructed wherever the JS SDK
/// is initialized (it must be passed to `Sentry.init()`'s `integrations`
/// list) -- this only types the one method called afterwards, per capture.
@internal
@JS()
extension type WebReplayCanvasIntegration._(JSObject _) implements JSObject {
  external void snapshot(web.HTMLCanvasElement canvasElement, [JSAny? options]);
}

@JS()
@anonymous
extension type _SnapshotOptions._(JSObject _) implements JSObject {
  external factory _SnapshotOptions({bool skipRequestAnimationFrame});
}

/// Real, DOM-touching implementation of [WebReplayCanvasBridge]. See that
/// interface for the contract; this class is exercised only by an
/// integration test (`example/integration_test`), not a unit test -- same
/// treatment JNI/FFI interop gets elsewhere in this SDK.
@internal
class RealWebReplayCanvasBridge implements WebReplayCanvasBridge {
  RealWebReplayCanvasBridge(this._canvasIntegration);

  final WebReplayCanvasIntegration _canvasIntegration;

  web.HTMLCanvasElement? _shadowCanvas;
  web.CanvasRenderingContext2D? _shadowCtx;

  // Offscreen scratch canvas for the incoming (possibly capture-scaled)
  // source frame. feedFrame draws+scales FROM this ONTO the shadow canvas
  // via drawImage rather than putImageData directly onto the shadow canvas
  // -- putImageData requires an exact size match and can't scale.
  web.HTMLCanvasElement? _sourceCanvas;
  web.CanvasRenderingContext2D? _sourceCtx;

  bool get isStarted => _shadowCanvas != null;

  @override
  void start() {
    if (isStarted) return;

    final shadow =
        web.document.createElement('canvas') as web.HTMLCanvasElement;
    shadow.id = webReplayShadowCanvasId;
    shadow.style.position = 'fixed';
    shadow.style.zIndex = '-1';
    web.document.body?.append(shadow);
    _shadowCanvas = shadow;
    _shadowCtx = shadow.getContext('2d') as web.CanvasRenderingContext2D;

    final source =
        web.document.createElement('canvas') as web.HTMLCanvasElement;
    _sourceCanvas = source;
    _sourceCtx = source.getContext('2d') as web.CanvasRenderingContext2D;
  }

  @override
  void updatePosition(ui.Rect rect, double devicePixelRatio) {
    final canvas = _shadowCanvas;
    if (canvas == null) return;

    canvas.style
      ..left = '${rect.left}px'
      ..top = '${rect.top}px'
      ..width = '${rect.width}px'
      ..height = '${rect.height}px';

    final targetWidth = (rect.width * devicePixelRatio).round();
    final targetHeight = (rect.height * devicePixelRatio).round();
    if (canvas.width != targetWidth || canvas.height != targetHeight) {
      canvas.width = targetWidth;
      canvas.height = targetHeight;
    }
  }

  @override
  void feedFrame(Uint8List rgba, int width, int height) {
    final source = _sourceCanvas;
    final sourceCtx = _sourceCtx;
    final shadow = _shadowCanvas;
    final shadowCtx = _shadowCtx;
    if (source == null ||
        sourceCtx == null ||
        shadow == null ||
        shadowCtx == null) {
      return;
    }

    if (source.width != width || source.height != height) {
      source.width = width;
      source.height = height;
    }

    final clamped = Uint8ClampedList.view(
            rgba.buffer, rgba.offsetInBytes, rgba.lengthInBytes)
        .toJS;
    final imageData = web.ImageData(clamped, width, height.toJS);
    sourceCtx.putImageData(imageData, 0, 0);

    shadowCtx.drawImage(
      source,
      0,
      0,
      width,
      height,
      0,
      0,
      shadow.width,
      shadow.height,
    );

    _canvasIntegration.snapshot(
        shadow, _SnapshotOptions(skipRequestAnimationFrame: true));
  }

  @override
  void stop() {
    _shadowCanvas?.remove();
    _shadowCanvas = null;
    _shadowCtx = null;
    _sourceCanvas = null;
    _sourceCtx = null;
  }
}
