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
import '../app_start_result.dart';
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
  AppStartResult? _firstFrame;
  DateTime? _startupStart;
  bool _nativeReady = false;
  bool _receivedFirstFrame = false;
  bool _recordedFirstFrame = false;

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
    final recorder = AppStartRecorder(clock: options.clock);
    _recorder = recorder;
    if (binding is SentryWidgetsBindingMixin) {
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
        // The root opens here and only learns its end at the first frame, so a
        // launch that is already implausible has to be rejected now — opening
        // a root that can never report a duration is worse than reporting
        // nothing.
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
    _startupStart = timing?.processStartTimestamp;
    _prepareTimeToDisplay(options, _startupStart);
    _nativeReady = true;
    if (options.standaloneAppStartTrace == null) {
      _detachFrameworkObserver();
      _recorder?.cancel();
      _recorder = null;
    }
    unawaited(_recordFirstFrame(options));
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

  /// Stops exposing the trace once it can no longer be extended, so a reported
  /// app start does not stay reachable — and retained — for the process
  /// lifetime.
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
          _receivedFirstFrame ||
          timings.isEmpty) {
        return;
      }
      _receivedFirstFrame = true;
      _firstFrame = AppStartResult.tryResolve(timings.first);
      _recorder?.freeze();
      _detachFrameworkObserver();
      _removeTimingsCallback();
      _startScreenName ??= SentryNavigatorObserver.currentRouteName;
      unawaited(_recordFirstFrame(options));
    }

    _timingsCallback = callback;
    _frameCallbackHandler.addTimingsCallback(callback);
  }

  Future<void> _recordFirstFrame(SentryFlutterOptions options) async {
    if (_closed ||
        !_nativeReady ||
        !_receivedFirstFrame ||
        _recordedFirstFrame) {
      return;
    }
    _recordedFirstFrame = true;
    final firstFrame = _firstFrame;
    _firstFrame = null;
    if (firstFrame == null) {
      _recorder?.cancel();
      _recorder = null;
      return;
    }
    try {
      final startupStart = _startupStart;
      final appStartResult = startupStart == null
          ? firstFrame
          : _recorder?.resolve(startupStart, firstFrame) ?? firstFrame;
      _recorder?.cancel();
      _recorder = null;
      options.standaloneAppStartTrace?.recordFirstFrame(
        firstFrame.rasterFinish,
        appStartResult: appStartResult,
      );
      await _displayTracking?.record(firstFrame.rasterFinish);
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

  void _stopObservation() {
    _removeTimingsCallback();
    _detachFrameworkObserver();
    _recorder?.cancel();
    _recorder = null;
    _firstFrame = null;
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
