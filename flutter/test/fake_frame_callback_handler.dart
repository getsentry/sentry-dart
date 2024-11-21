import 'package:flutter/scheduler.dart';
import 'package:sentry_flutter/src/frame_callback_handler.dart';

class FakeFrameCallbackHandler implements FrameCallbackHandler {
  FakeFrameCallbackHandler({this.postFrameCallbackDelay});

  /// If set, it automatically executes the callback after the delay
  Duration? postFrameCallbackDelay;
  FrameCallback? postFrameCallback;
  TimingsCallback? timingsCallback;

  @override
  void addPostFrameCallback(FrameCallback callback) async {
    postFrameCallback = callback;

    if (postFrameCallbackDelay != null) {
      await Future<void>.delayed(postFrameCallbackDelay!);
      callback(Duration.zero);
    }
  }

  @override
  void addTimingsCallback(TimingsCallback callback) {
    timingsCallback = callback;
  }

  @override
  void removeTimingsCallback(TimingsCallback callback) {
    if (timingsCallback == callback) {
      timingsCallback = null;
    }
  }
}
