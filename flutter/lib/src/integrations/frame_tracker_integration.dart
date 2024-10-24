import 'package:flutter/cupertino.dart';

import '../../sentry_flutter.dart';
import '../frame_tracking/sentry_delayed_frames_tracker.dart';
import '../frame_tracking/sentry_frame_tracking_binding_mixin.dart';
import '../frame_tracking/span_frame_metrics_collector.dart';
import '../native/sentry_native_binding.dart';

class FrameTrackerIntegration implements Integration<SentryFlutterOptions> {
  FrameTrackerIntegration(this._native);

  final SentryNativeBinding _native;

  @override
  void call(Hub hub, SentryFlutterOptions options) async {
    if (!options.enableFramesTracking) {
      return;
    }

    if (!options.isTracingEnabled()) {
      return;
    }

    if (WidgetsBinding.instance is! SentryWidgetsFlutterBinding) {
      return;
    }

    final expectedFrameDuration = await _initializeExpectedFrameDuration();
    if (expectedFrameDuration == null) {
      return;
    }

    _initializeFrameTracking(options, expectedFrameDuration);
    options.sdk.addIntegration('frameTrackerIntegration');
  }

  void _initializeFrameTracking(
      SentryFlutterOptions options, Duration expectedFrameDuration) {
    final frameTracker =
        SentryDelayedFramesTracker(options, expectedFrameDuration);
    SentryFrameTrackingBindingMixin.initializeFrameTracker(frameTracker);
    final collector = SpanFrameMetricsCollector(
      options,
      frameTracker,
    );

    options.addPerformanceCollector(collector);
  }

  Future<Duration?> _initializeExpectedFrameDuration() async {
    final displayRefreshRate = await _native.displayRefreshRate();
    if (displayRefreshRate == null || displayRefreshRate <= 0) {
      return null;
    }
    return Duration(milliseconds: ((1 / displayRefreshRate) * 1000).toInt());
  }

  @override
  void close() {}
}
