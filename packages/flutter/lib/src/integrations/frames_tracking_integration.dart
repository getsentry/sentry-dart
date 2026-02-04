// ignore_for_file: invalid_use_of_internal_member, deprecated_member_use

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
  SdkLifecycleCallback<OnSpanStartV2>? _onSpanStartCallback;
  SdkLifecycleCallback<OnProcessSpan>? _onProcessSpanCallback;
  SdkLifecycleCallback<OnSpanStart>? _onSpanStartStaticCallback;
  SdkLifecycleCallback<OnSpanFinish>? _onSpanFinishStaticCallback;

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
    switch (options.traceLifecycle) {
      case SentryTraceLifecycle.streaming:
        final collector = SpanFrameMetricsCollectorV2(framesTracker,
            resumeFrameTracking: () => widgetsBinding.resumeTrackingFrames(),
            pauseFrameTracking: () => widgetsBinding.pauseTrackingFrames());
        _collector = collector;

        _onSpanStartCallback = (event) {
          collector.onSpanStarted(event.span);
        };
        options.lifecycleRegistry
            .registerCallback<OnSpanStartV2>(_onSpanStartCallback!);

        _onProcessSpanCallback = (event) {
          if (event.span.endTimestamp != null) {
            collector.onSpanFinished(event.span, event.span.endTimestamp!);
          }
        };
        options.lifecycleRegistry
            .registerCallback<OnProcessSpan>(_onProcessSpanCallback!);
      case SentryTraceLifecycle.static:
        final collector = SpanFrameMetricsCollector(options, framesTracker,
            resumeFrameTracking: () => widgetsBinding.resumeTrackingFrames(),
            pauseFrameTracking: () => widgetsBinding.pauseTrackingFrames());
        _collector = collector;

        _onSpanStartStaticCallback = (event) async {
          await collector.onSpanStarted(event.span);
        };
        options.lifecycleRegistry
            .registerCallback<OnSpanStart>(_onSpanStartStaticCallback!);

        _onSpanFinishStaticCallback = (event) async {
          await collector.onSpanFinished(event.span, event.endTimestamp);
        };
        options.lifecycleRegistry
            .registerCallback<OnSpanFinish>(_onSpanFinishStaticCallback!);
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
    final options = _options;
    if (options != null) {
      if (_onSpanStartCallback != null) {
        options.lifecycleRegistry
            .removeCallback<OnSpanStartV2>(_onSpanStartCallback!);
        _onSpanStartCallback = null;
      }
      if (_onProcessSpanCallback != null) {
        options.lifecycleRegistry
            .removeCallback<OnProcessSpan>(_onProcessSpanCallback!);
        _onProcessSpanCallback = null;
      }
      if (_onSpanStartStaticCallback != null) {
        options.lifecycleRegistry
            .removeCallback<OnSpanStart>(_onSpanStartStaticCallback!);
        _onSpanStartStaticCallback = null;
      }
      if (_onSpanFinishStaticCallback != null) {
        options.lifecycleRegistry
            .removeCallback<OnSpanFinish>(_onSpanFinishStaticCallback!);
        _onSpanFinishStaticCallback = null;
      }
    }
    final collector = _collector;
    if (collector is PerformanceContinuousCollector) {
      collector.clear();
    } else if (collector is PerformanceContinuousCollectorV2) {
      collector.clear();
    }
    _widgetsBinding?.removeFramesTracking();
  }
}
