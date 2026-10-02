import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

import '../../replay/scheduled_recorder.dart';
import '../../screenshot/screenshot.dart';
import '../../screenshot/sentry_screenshot_widget.dart'
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
  SentryWebReplayRecorder(super.options,
      {required WebReplayCanvasBridge bridge})
      : _bridge = bridge {
    super.callback = _onScreenshot;
  }

  final WebReplayCanvasBridge _bridge;

  // See the comment on ScreenshotRecorder.yieldToEventLoop: the default
  // no-op preserves every other recorder's behavior; only web's pipeline
  // shares a thread with anything else that needs a chance to run.
  @override
  Future<void> yieldToEventLoop() => Future.delayed(Duration.zero);

  @override
  Future<void> start() async {
    _bridge.start();
    await super.start();
  }

  @override
  Future<void> stop() async {
    await super.stop();
    _bridge.stop();
  }

  Future<void> _onScreenshot(
      Screenshot screenshot, bool isNewlyCaptured) async {
    try {
      // Read the boundary's current on-screen rect before the async gap
      // below -- per the documented invariant on ScreenshotRecorder.capture,
      // reading mutable render-tree state after an await can be stale. The
      // whole-app boundary's own position/size changes far less often than
      // a moving mask rect, but there's no reason to take the risk here
      // either.
      final renderObject = sentryScreenshotWidgetGlobalKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (renderObject == null) return;
      final topLeft = renderObject.localToGlobal(Offset.zero);
      final rect = ui.Rect.fromLTWH(topLeft.dx, topLeft.dy,
          renderObject.size.width, renderObject.size.height);
      final devicePixelRatio =
          ui.PlatformDispatcher.instance.views.first.devicePixelRatio;

      final data = await screenshot.rawRgbaData;

      _bridge.updatePosition(rect, devicePixelRatio);
      _bridge.feedFrame(
          data.buffer.asUint8List(), screenshot.width, screenshot.height);
    } catch (error, stackTrace) {
      internalLogger.error('$logName: failed to feed replay frame',
          error: error, stackTrace: stackTrace);
      if (options.automatedTestMode) {
        rethrow;
      }
    }
  }
}
