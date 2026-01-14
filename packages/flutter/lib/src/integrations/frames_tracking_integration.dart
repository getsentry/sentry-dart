// ignore_for_file: invalid_use_of_internal_member

import 'dart:core';

import '../../sentry_flutter.dart';
import '../binding_wrapper.dart';
import '../frames_tracking/sentry_delayed_frames_tracker.dart';
import '../frames_tracking/span_frame_metrics_collector.dart';
import '../frames_tracking/span_frame_metrics_collector_v2.dart';
import '../native/sentry_native_binding.dart';

class FramesTrackingIntegration implements Integration<SentryFlutterOptions> {
  FramesTrackingIntegration(this._native);

  static const integrationName = 'FramesTracking';
  final SentryNativeBinding _native;
  SentryFlutterOptions? _options;
  PerformanceCollector? _collector;
  SentryWidgetsBindingMixin? _widgetsBinding;

  @override
  Future<void> call(Hub hub, SentryFlutterOptions options) async {
    _options = options;

    if (!options.enableFramesTracking) {
      return options.log(SentryLevel.debug,
          '$FramesTrackingIntegration disabled: enableFramesTracking option is false');
    }

    if (options.tracesSampleRate == null && options.tracesSampler == null) {
      return options.log(SentryLevel.debug,
          '$FramesTrackingIntegration disabled: tracesSampleRate and tracesSampler are disabled');
    }

    final widgetsBinding = options.bindingUtils.instance;
    if (widgetsBinding == null ||
        widgetsBinding is! SentryWidgetsBindingMixin) {
      return options.log(SentryLevel.warning,
          '$FramesTrackingIntegration disabled: incompatible binding, SentryWidgetsFlutterBinding has not been instantiated. Please, use SentryWidgetsFlutterBinding.ensureInitialized() instead of WidgetsFlutterBinding.ensureInitialized()');
    }
    _widgetsBinding = widgetsBinding;

    final expectedFrameDuration = await _initializeExpectedFrameDuration();
    if (expectedFrameDuration == null) {
      return options.log(SentryLevel.debug,
          '$FramesTrackingIntegration disabled: could not fetch valid display refresh rate');
    }

    // Everything valid, we can initialize now
    final framesTracker =
        SentryDelayedFramesTracker(options, expectedFrameDuration);
    widgetsBinding.initializeFramesTracking(
        framesTracker.addDelayedFrame, options, expectedFrameDuration);
    if (options.traceLifecycle == SentryTraceLifecycle.streaming) {
      final collector = SpanFrameMetricsCollectorV2(framesTracker,
          resumeFrameTracking: () => widgetsBinding.resumeTrackingFrames(),
          pauseFrameTracking: () => widgetsBinding.pauseTrackingFrames());
      _collector = collector;

      options.lifecycleRegistry.registerCallback<OnSpanStartV2>((event) {
        collector.onSpanStarted(event.span);
      });

      options.lifecycleRegistry.registerCallback<OnSpanEndV2>((event) {
        if (event.span.endTimestamp != null) {
          collector.onSpanFinished(event.span, event.span.endTimestamp!);
        }
      });
    } else {
      final collector = SpanFrameMetricsCollector(options, framesTracker,
          resumeFrameTracking: () => widgetsBinding.resumeTrackingFrames(),
          pauseFrameTracking: () => widgetsBinding.pauseTrackingFrames());
      options.addPerformanceCollector(collector);
      _collector = collector;
    }

    options.sdk.addIntegration(integrationName);
    options.log(SentryLevel.debug,
        '$FramesTrackingIntegration successfully initialized with an expected frame duration of ${expectedFrameDuration.inMilliseconds}ms');
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
    _widgetsBinding?.removeFramesTracking();
  }
}
