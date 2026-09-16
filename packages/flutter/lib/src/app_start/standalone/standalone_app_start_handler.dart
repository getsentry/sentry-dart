// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'dart:async';
import 'dart:ui';

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../frame_callback_handler.dart';
import '../../binding_wrapper.dart';
import '../app_start_recorder.dart';
import '../../native/sentry_native_binding.dart';
import '../../navigation/root_route.dart';
import '../../utils/internal_logger.dart';
import '../app_start_timing.dart';
import 'app_start_display_tracking.dart';
import 'app_start_trace.dart';
import 'static_app_start_trace.dart';
import 'streaming_app_start_trace.dart';

/// Owns standalone app-start tracing from native timing through first display.
@internal
class StandaloneAppStartHandler {
  final Hub _hub;
  final FrameCallbackHandler _frameCallbackHandler;
  final SentryNativeBinding _native;

  String? _startScreenName;
  TimingsCallback? _timingsCallback;
  SentryFlutterOptions? _options;

  /// Set by [_prepareTimeToDisplay]; `null` until then.
  AppStartDisplayTracking? _displayTracking;

  AppStartRecorder? _recorder;
  SentryWidgetsBindingMixin? _recordingBinding;
  AppStartRecordedInterval? _pendingRasterInterval;
  DateTime? _processStartTimestamp;
  // Resolution can complete without usable timing data.
  bool _nativeTimingResolved = false;
  bool _rasterTimingResolved = false;

  bool _started = false;
  bool _closed = false;

  StandaloneAppStartHandler({
    Hub? hub,
    FrameCallbackHandler? frameCallbackHandler,
    required this._native,
  }) : _hub = hub ?? HubAdapter(),
       _frameCallbackHandler =
           frameCallbackHandler ?? DefaultFrameCallbackHandler();

  Future<void> start(SentryFlutterOptions options) async {
    if (_closed || _started) {
      return;
    }
    _started = true;
    _options = options;

    final binding = options.bindingUtils.instance;
    // A pending raster callback is not proof that rendering has not started.
    // Requiring an unattached root rejects the submission-to-callback window.
    if (binding == null ||
        binding.rootElement != null ||
        binding.firstFrameRasterized) {
      internalLogger.info(
        'Skipping app start: first-frame observation began too late',
      );
      return;
    }
    if (binding is SentryWidgetsBindingMixin) {
      final recorder = AppStartRecorder(clock: options.clock);
      _recorder = recorder;
      _recordingBinding = binding;
      binding.startAppStartRecording(recorder);
    }
    try {
      _registerFirstFrameCallback(options);
    } catch (_) {
      _stopObservation();
      rethrow;
    }

    AppStartTiming? timing;
    try {
      final nativeAppStart = await _native.fetchNativeAppStart();
      if (_closed) {
        return;
      }

      final setupTimestamp = SentryFlutter.sentrySetupStartTime;
      if (nativeAppStart != null && setupTimestamp != null) {
        final parsed = AppStartTiming.tryParse(
          nativeAppStart,
          sentrySetupTimestamp: setupTimestamp,
        );
        // Reject launches already too old before opening the root.
        if (parsed?.reportableDurationUntil(options.clock()) != null) {
          timing = parsed;
        }
      }
    } catch (error, stackTrace) {
      internalLogger.error(
        'Failed to fetch standalone app-start timing',
        error: error,
        stackTrace: stackTrace,
      );
    }

    // Re-checked because a throw above skips the in-try check.
    if (_closed) {
      return;
    }

    if (timing == null) {
      internalLogger.info(
        'Skipping standalone app start: native timing unavailable or invalid',
      );
    } else {
      final trace = _createAppStartTrace(options, timing);
      if (trace == null) {
        internalLogger.info(
          'Skipping standalone app start: trace was not created',
        );
      } else {
        options.standaloneAppStartTrace = trace;
      }
    }

    // Runs even without a trace, so the initial route still reports its
    // display timings.
    _processStartTimestamp = timing?.processStartTimestamp;
    _prepareTimeToDisplay(options, _processStartTimestamp);
    _nativeTimingResolved = true;
    if (options.standaloneAppStartTrace == null) {
      _detachFrameworkObserver();
      _disposeRecorder();
    }
    unawaited(_recordStartupWhenReady(options));
  }

  AppStartTrace? _createAppStartTrace(
    SentryFlutterOptions options,
    AppStartTiming timing,
  ) {
    // Resolve the app-start screen name during trace enrichment, not trace
    // creation. Its route is captured only at the first valid frame.
    return switch (options.traceLifecycle) {
      SentryTraceLifecycle.static => StaticAppStartTrace.tryCreate(
        hub: _hub,
        timing: timing,
        startScreenNameProvider: _resolveStartScreenName,
        onCompleted: _unpublishTrace,
      ),
      SentryTraceLifecycle.stream => StreamingAppStartTrace.tryCreate(
        hub: _hub,
        timing: timing,
        startScreenNameProvider: _resolveStartScreenName,
        onCompleted: _unpublishTrace,
      ),
    };
  }

  /// Releases the completed trace and stops observing startup.
  void _unpublishTrace() {
    _options?.standaloneAppStartTrace = null;
    _stopObservation();
  }

  String _resolveStartScreenName() => resolveRouteDisplayName(_startScreenName);

  void _prepareTimeToDisplay(
    SentryFlutterOptions options,
    DateTime? startTimestamp,
  ) {
    final resolvedStartTimestamp =
        startTimestamp ?? SentryFlutter.sentrySetupStartTime ?? options.clock();

    final displayTracking = AppStartDisplayTracking.forOptions(options);
    _displayTracking = displayTracking;
    displayTracking.prepare(resolvedStartTimestamp);
  }

  void _registerFirstFrameCallback(SentryFlutterOptions options) {
    void callback(List<FrameTiming> timings) {
      if (_closed ||
          _timingsCallback == null ||
          _rasterTimingResolved ||
          timings.isEmpty) {
        return;
      }
      _rasterTimingResolved = true;
      _pendingRasterInterval = tryResolveAppStartRasterInterval(timings.first);
      _recorder?.freeze();
      _detachFrameworkObserver();
      _removeTimingsCallback();
      _startScreenName ??= SentryNavigatorObserver.currentRouteName;
      unawaited(_recordStartupWhenReady(options));
    }

    _timingsCallback = callback;
    _frameCallbackHandler.addTimingsCallback(callback);
  }

  Future<void> _recordStartupWhenReady(SentryFlutterOptions options) async {
    if (_closed || !_nativeTimingResolved || !_rasterTimingResolved) {
      return;
    }
    // Consume before awaiting display tracking so this result is handled once.
    final rasterInterval = _pendingRasterInterval;
    _pendingRasterInterval = null;
    final processStart = _processStartTimestamp;
    if (rasterInterval == null ||
        (processStart != null &&
            rasterInterval.startTimestamp.isBefore(processStart))) {
      _disposeRecorder();
      options.standaloneAppStartTrace?.recordFirstFrame(null);
      return;
    }
    try {
      final recorder = _recorder;
      final frameworkIntervals = processStart != null && recorder != null
          ? recorder.takeIntervals(
              processStart: processStart,
              rasterFinish: rasterInterval.endTimestamp,
            )
          : const <AppStartRecordedInterval>[];
      _disposeRecorder();
      options.standaloneAppStartTrace?.recordFirstFrame(
        rasterInterval,
        frameworkIntervals: frameworkIntervals,
      );
      await _displayTracking?.record(rasterInterval.endTimestamp);
    } catch (error, stackTrace) {
      internalLogger.error(
        'Failed to record standalone app-start first frame',
        error: error,
        stackTrace: stackTrace,
      );
      if (options.automatedTestMode) rethrow;
    }
  }

  void _detachFrameworkObserver() {
    final recorder = _recorder;
    if (recorder != null) _recordingBinding?.stopAppStartRecording(recorder);
    _recordingBinding = null;
  }

  void _disposeRecorder() {
    _recorder?.cancel();
    _recorder = null;
  }

  void _stopObservation() {
    _removeTimingsCallback();
    _detachFrameworkObserver();
    _disposeRecorder();
    _pendingRasterInterval = null;
  }

  Future<void> close() async {
    _closed = true;
    _stopObservation();
    // Read before closing: a trace that reports while closing unpublishes
    // itself, and this teardown still has to await the one it started with.
    final trace = _options?.standaloneAppStartTrace;
    await trace?.close();
    _unpublishTrace();
    _displayTracking?.cancel();
    _displayTracking = null;
    _startScreenName = null;
  }

  void _removeTimingsCallback() {
    final timingsCallback = _timingsCallback;
    if (timingsCallback == null) {
      return;
    }

    _frameCallbackHandler.removeTimingsCallback(timingsCallback);
    _timingsCallback = null;
  }
}
