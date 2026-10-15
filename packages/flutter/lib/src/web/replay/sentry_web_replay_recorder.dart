import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import '../../replay/scheduled_recorder.dart';
import '../../replay/scheduled_recorder_config.dart';
import '../../screen_capture/screenshot.dart';
import '../../screen_capture/sentry_screenshot_widget.dart'
    show sentryScreenshotWidgetGlobalKey;
import '../../utils/internal_logger.dart';
import 'web_replay_canvas_bridge.dart';

/// Flutter Web's replay recorder (#2897).
///
/// Reuses the same capture+masking pipeline every other platform's replay
/// recorder does ([ScheduledScreenshotRecorder]/[Screenshot.rawRgbaData]) --
/// the only web-specific parts are (a) forcing real macrotask yields between
/// capture phases via [yieldToEventLoop], required because this pipeline
/// runs on the browser's own main thread rather than an isolate, and (b)
/// handing each masked frame to a [WebReplayCanvasBridge] instead of a
/// native worker.
@internal
class SentryWebReplayRecorder extends ScheduledScreenshotRecorder {
  SentryWebReplayRecorder(
    super.options, {
    required this._bridge,
    required this._isRecording,
  }) {
    super.callback = _onScreenshot;
  }

  final WebReplayCanvasBridge _bridge;
  final bool Function() _isRecording;

  // The JS replay may not be recording: the session wasn't sampled, or the
  // JS SDK stopped it on its own (session expiry, max duration). Capturing
  // and masking then only costs main-thread time, so skip it until the JS
  // replay records again.
  @override
  bool get shouldCapture => _isRecording();

  // See the comment on ScreenshotRecorder.yieldToEventLoop: the default
  // no-op preserves every other recorder's behavior; only web's pipeline
  // shares a thread with anything else that needs a chance to run.
  @override
  Future<void> yieldToEventLoop() => Future.delayed(Duration.zero);

  bool _started = false;
  int? _frameRate;

  @override
  Future<void> start() async {
    _bridge.start();
    await super.start();
    _started = true;
  }

  @override
  Future<void> stop() async {
    _started = false;
    await super.stop();
    _bridge.stop();
  }

  // The base class restarts the scheduler on every config change, and a
  // fresh scheduler captures on the very next frame. A window drag or
  // rotation changes the config every frame, so that would capture -- and
  // resize the shadow canvas, which rrweb records immediately -- at frame
  // rate, while rrweb's own snapshot throttling drops most of the matching
  // draws. That desyncs canvas size from its content in the recording.
  // Instead, keep the cadence: capture() reads [config] on every run, so the
  // next scheduled capture already uses the new size.
  @override
  Future<void> onConfigurationChanged(
    ScheduledScreenshotRecorderConfig config,
  ) async {
    final frameRateUnchanged = config.frameRate == _frameRate;
    _frameRate = config.frameRate;
    if (_started && frameRateUnchanged) {
      super.config = config;
      return;
    }
    await super.onConfigurationChanged(config);
  }

  Future<void> _onScreenshot(
    Screenshot screenshot,
    bool isNewlyCaptured,
  ) async {
    try {
      // Read the boundary's current on-screen rect before the async gap
      // below -- per the documented invariant on ScreenshotRecorder.capture,
      // reading mutable render-tree state after an await can be stale. The
      // whole-app boundary's own position/size changes far less often than
      // a moving mask rect, but there's no reason to take the risk here
      // either.
      final renderObject =
          sentryScreenshotWidgetGlobalKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (renderObject == null) return;
      final topLeft = renderObject.localToGlobal(Offset.zero);
      final rect = ui.Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy,
        renderObject.size.width,
        renderObject.size.height,
      );
      final devicePixelRatio =
          ui.PlatformDispatcher.instance.views.first.devicePixelRatio;

      final data = await screenshot.rawRgbaData;

      _bridge.updatePosition(rect, devicePixelRatio);
      _bridge.feedFrame(
        data.buffer.asUint8List(),
        screenshot.width,
        screenshot.height,
      );
    } catch (error, stackTrace) {
      internalLogger.error(
        '$logName: failed to feed replay frame',
        error: error,
        stackTrace: stackTrace,
      );
      if (options.automatedTestMode) {
        rethrow;
      }
    }
  }
}
