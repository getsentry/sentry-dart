// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'dart:ui';

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../frame_callback_handler.dart';
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
    _prepareTimeToDisplay(options, timing?.processStartTimestamp);
    _registerFirstFrameCallback(options);
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
  void _unpublishTrace() => _options?.standaloneAppStartTrace = null;

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
    void callback(List<FrameTiming> timings) async {
      if (_closed || timings.isEmpty) return;

      final endTimestamp = DateTime.fromMicrosecondsSinceEpoch(
        timings.first.timestampInMicroseconds(FramePhase.rasterFinishWallTime),
      );

      _removeTimingsCallback();

      try {
        // Freeze the launch screen during first frame before enrichment;
        // the user may navigate away before the app-start span finishes.
        _startScreenName ??= SentryNavigatorObserver.currentRouteName;

        options.standaloneAppStartTrace?.recordFirstFrame(endTimestamp);

        // Keep display tracking last because TTFD may wait for its timeout.
        await _displayTracking?.record(endTimestamp);
      } catch (error, stackTrace) {
        internalLogger.error(
          'Failed to record standalone app-start first frame',
          error: error,
          stackTrace: stackTrace,
        );
        if (options.automatedTestMode) {
          rethrow;
        }
      }
    }

    _timingsCallback = callback;
    _frameCallbackHandler.addTimingsCallback(callback);
  }

  Future<void> close() async {
    _closed = true;
    _removeTimingsCallback();
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
