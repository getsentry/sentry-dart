import 'package:flutter/cupertino.dart';
import 'sentry_delayed_frames_tracker.dart';

mixin SentryFrameTrackingBindingMixin on WidgetsBinding {
  static SentryDelayedFramesTracker? get frameTracker => _frameTracker;
  static SentryDelayedFramesTracker? _frameTracker;

  static void initializeFrameTracker(SentryDelayedFramesTracker frameTracker) {
    _frameTracker ??= frameTracker;
  }

  @override
  void handleBeginFrame(Duration? rawTimeStamp) {
    _frameTracker?.startFrame();

    super.handleBeginFrame(rawTimeStamp);
  }

  @override
  void handleDrawFrame() {
    super.handleDrawFrame();

    _frameTracker?.endFrame();
  }
}
