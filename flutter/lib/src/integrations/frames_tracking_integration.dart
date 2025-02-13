// ignore_for_file: invalid_use_of_internal_member

import '../../sentry_flutter.dart';
import '../binding_wrapper.dart';
import '../frames_tracking/sentry_delayed_frames_tracker.dart';
import '../frames_tracking/span_frame_metrics_collector.dart';
import '../native/sentry_native_binding.dart';

class FramesTrackingIntegration implements Integration<SentryFlutterOptions> {
  FramesTrackingIntegration(this._native);

  final SentryNativeBinding _native;
  SentryFlutterOptions? _options;
  PerformanceCollector? _collector;
  SentryWidgetsBindingMixin? _widgetsBinding;

  @override
  Future<void> call(Hub hub, SentryFlutterOptions options) async {
    _options = options;

    if (!options.enableFramesTracking) {
      return options.logger(SentryLevel.debug,
          '$FramesTrackingIntegration disabled: enableFramesTracking option is false');
    }

    if (options.tracesSampleRate == null && options.tracesSampler == null) {
      return options.logger(SentryLevel.debug,
          '$FramesTrackingIntegration disabled: tracesSampleRate and tracesSampler are disabled');
    }

    final widgetsBinding = options.bindingUtils.instance;
    if (widgetsBinding == null ||
        widgetsBinding is! SentryWidgetsBindingMixin) {
      return options.logger(SentryLevel.warning,
          '$FramesTrackingIntegration disabled: incompatible binding, SentryWidgetsFlutterBinding has not been instantiated. Please, use SentryWidgetsFlutterBinding.ensureInitialized() instead of WidgetsFlutterBinding.ensureInitialized()');
    }
    _widgetsBinding = widgetsBinding;

    final expectedFrameDuration = await _initializeExpectedFrameDuration();
    if (expectedFrameDuration == null) {
      return options.logger(SentryLevel.debug,
          '$FramesTrackingIntegration disabled: could not fetch valid display refresh rate');
    }

    // Everything valid, we can initialize now
    final framesTracker =
        SentryDelayedFramesTracker(options, expectedFrameDuration);
    widgetsBinding.registerFramesTracking(
        framesTracker.addFrame, options.clock);
    final collector = SpanFrameMetricsCollector(options, framesTracker);
    options.addPerformanceCollector(collector);
    _collector = collector;

    options.sdk.addIntegration('framesTrackingIntegration');
    options.logger(SentryLevel.debug,
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
