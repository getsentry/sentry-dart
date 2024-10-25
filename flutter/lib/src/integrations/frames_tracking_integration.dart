import 'package:flutter/cupertino.dart';

import '../../sentry_flutter.dart';
import '../binding_wrapper.dart';
import '../frames_tracking/sentry_delayed_frames_tracker.dart';
import '../frames_tracking/span_frame_metrics_collector.dart';
import '../native/sentry_native_binding.dart';

class FramesTrackingIntegration implements Integration<SentryFlutterOptions> {
  FramesTrackingIntegration(
    this._native, {
    bool Function(WidgetsBinding binding)? isCompatibleBinding,
  }) : _isCompatibleBinding = isCompatibleBinding ??
            ((binding) => binding is SentryWidgetsFlutterBinding);

  final SentryNativeBinding _native;
  final bool Function(WidgetsBinding binding) _isCompatibleBinding;

  SentryFlutterOptions? _options;
  PerformanceCollector? _collector;

  @override
  Future<void> call(Hub hub, SentryFlutterOptions options) async {
    _options = options;

    void abortInitWith({required String reason}) {
      options.logger(SentryLevel.debug,
          '$FramesTrackingIntegration is disabled: $reason.');
    }

    if (!options.enableFramesTracking) {
      return abortInitWith(reason: 'option enablesFrameTracking is false');
    }

    if (options.tracesSampleRate == null && options.tracesSampler == null) {
      return abortInitWith(reason: 'tracing is disabled');
    }

    if (!_isCompatibleBinding(WidgetsBinding.instance)) {
      return abortInitWith(
          reason: 'SentryFlutterWidgetsBinding has not been instantiated');
    }

    final expectedFrameDuration = await _initializeExpectedFrameDuration();
    if (expectedFrameDuration == null) {
      return abortInitWith(
          reason: 'could not fetch valid display refresh rate');
    }

    _initializeFrameTracking(options, expectedFrameDuration);
    options.sdk.addIntegration('framesTrackingIntegration');
    options.logger(SentryLevel.debug,
        'Frames tracking successfully initialized with an expected frame duration of ${expectedFrameDuration.inMilliseconds}ms');
  }

  void _initializeFrameTracking(
      SentryFlutterOptions options, Duration expectedFrameDuration) {
    final framesTracker =
        SentryDelayedFramesTracker(options, expectedFrameDuration);
    SentryWidgetsBindingMixin.initializeFramesTracker(framesTracker);
    final collector = SpanFrameMetricsCollector(
      options,
      framesTracker,
    );
    _collector = collector;
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
  void close() {
    _options?.performanceCollectors.remove(_collector);
    SentryWidgetsBindingMixin.clearFramesTracker();
  }
}
