import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:meta/meta.dart';
import 'package:web/web.dart' as web;

import '../../utils/internal_logger.dart';
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

  // Whether rrweb may already have recorded a draw of the current shadow
  // canvas -- from then on, a size change needs a new element (see
  // [updatePosition]).
  bool _snapshotted = false;

  // Whether the current shadow canvas was added in this task, before rrweb's
  // MutationObserver has registered it. rrweb skips snapshots of canvases
  // it doesn't know yet.
  bool _awaitingRegistration = false;

  bool get isStarted => _shadowCanvas != null;

  @override
  void start() {
    if (isStarted) return;

    final shadow = _createShadowCanvas();
    web.document.body?.append(shadow);
    _setShadowCanvas(shadow);

    final source =
        web.document.createElement('canvas') as web.HTMLCanvasElement;
    _sourceCanvas = source;
    _sourceCtx = source.getContext('2d') as web.CanvasRenderingContext2D;
  }

  @override
  void updatePosition(ui.Rect rect, double devicePixelRatio) {
    final current = _shadowCanvas;
    if (current == null) return;

    final targetWidth = (rect.width * devicePixelRatio).round();
    final targetHeight = (rect.height * devicePixelRatio).round();
    final resize =
        current.width != targetWidth || current.height != targetHeight;

    // Sentry's replay player clones a canvas on its first recorded draw and
    // keeps drawing into that clone, so later width/height changes never
    // reach it: smaller frames only cover its top-left corner, leaving the
    // previous frame's leftovers around them. A new element gets a fresh
    // clone at the new size.
    final replace = resize && _snapshotted;
    final canvas = replace ? _createShadowCanvas() : current;

    canvas.style
      ..left = '${rect.left}px'
      ..top = '${rect.top}px'
      ..width = '${rect.width}px'
      ..height = '${rect.height}px';

    if (resize) {
      canvas.width = targetWidth;
      canvas.height = targetHeight;
    }

    // Sized before it's attached, so rrweb records it at its final size.
    if (replace) {
      current.remove();
      web.document.body?.append(canvas);
      _setShadowCanvas(canvas);
      _awaitingRegistration = true;
    }
  }

  web.HTMLCanvasElement _createShadowCanvas() {
    final canvas =
        web.document.createElement('canvas') as web.HTMLCanvasElement;
    canvas.id = webReplayShadowCanvasId;
    canvas.style.position = 'fixed';
    canvas.style.zIndex = '-1';
    return canvas;
  }

  void _setShadowCanvas(web.HTMLCanvasElement canvas) {
    _shadowCanvas = canvas;
    _shadowCtx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    _snapshotted = false;
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
      rgba.buffer,
      rgba.offsetInBytes,
      rgba.lengthInBytes,
    ).toJS;
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

    if (_awaitingRegistration) {
      Timer.run(() {
        _awaitingRegistration = false;
        // Stopped or replaced again in the meantime.
        if (_shadowCanvas != shadow) return;
        // Runs outside the recorder's error handling around feedFrame.
        try {
          _snapshot(shadow);
        } catch (error, stackTrace) {
          internalLogger.error(
            'Failed to snapshot the replaced replay canvas',
            error: error,
            stackTrace: stackTrace,
          );
        }
      });
    } else {
      _snapshot(shadow);
    }
  }

  void _snapshot(web.HTMLCanvasElement shadow) {
    _snapshotted = true;
    _canvasIntegration.snapshot(
      shadow,
      _SnapshotOptions(skipRequestAnimationFrame: true),
    );
  }

  @override
  void stop() {
    _shadowCanvas?.remove();
    _shadowCanvas = null;
    _shadowCtx = null;
    _snapshotted = false;
    _awaitingRegistration = false;
    _sourceCanvas = null;
    _sourceCtx = null;
  }
}
