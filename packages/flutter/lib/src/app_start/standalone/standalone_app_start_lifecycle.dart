// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'dart:ui';

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../frame_callback_handler.dart';
import '../../native/sentry_native_binding.dart';
import '../../navigation/root_route.dart';
import '../../utils/internal_logger.dart';
import '../app_start_data.dart';
import 'app_start_trace.dart';
import 'static_app_start_trace.dart';
import 'streaming_app_start_trace.dart';

/// Owns standalone app-start tracing from native timing through first display.
@internal
class StandaloneAppStartLifecycle {
  final Hub _hub;
  final FrameCallbackHandler _frameCallbackHandler;
  final SentryNativeBinding _native;

  AppStartTrace? _trace;
  String? _startScreenName;
  TimingsCallback? _timingsCallback;

  /// Tears down whatever [_prepareTimeToDisplay] set up, if anything.
  void Function()? _cancelPreparedDisplay;
  bool _started = false;
  bool _closed = false;

  SentryFlutterOptions? get _flutterOptions {
    final options = _hub.options;
    return options is SentryFlutterOptions ? options : null;
  }

  StandaloneAppStartLifecycle({
    Hub? hub,
    FrameCallbackHandler? frameCallbackHandler,
    required SentryNativeBinding native,
  })  : _hub = hub ?? HubAdapter(),
        _frameCallbackHandler =
            frameCallbackHandler ?? DefaultFrameCallbackHandler(),
        _native = native;

  Future<void> start() async {
    if (_closed || _started) {
      return;
    }
    _started = true;

    AppStartData? data;
    try {
      final nativeAppStart = await _native.fetchNativeAppStart();
      if (_closed) {
        return;
      }

      final setupTimestamp = SentryFlutter.sentrySetupStartTime;
      final snapshotTimestamp = _flutterOptions?.clock();
      if (nativeAppStart != null &&
          setupTimestamp != null &&
          snapshotTimestamp != null) {
        data = AppStartData.tryParseAtSnapshot(
          nativeAppStart,
          sentrySetupTimestamp: setupTimestamp,
          snapshotTimestamp: snapshotTimestamp,
        );
      }
    } catch (error, stackTrace) {
      internalLogger.error(
        'Failed to fetch standalone app-start timing',
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (_closed) {
      return;
    }

    if (data == null) {
      internalLogger.info(
        'Skipping standalone app start: native timing unavailable or invalid',
      );
    } else {
      final trace = _createAppStartTrace(data);
      if (trace == null) {
        internalLogger.info(
          'Skipping standalone app start: trace was not created',
        );
      } else {
        _trace = trace;
      }
    }

    _prepareTimeToDisplay(
      data?.processStartTimestamp ?? SentryFlutter.sentrySetupStartTime,
    );
    _recordFirstFrame();
  }

  AppStartTrace? _createAppStartTrace(AppStartData data) {
    final options = _flutterOptions;
    if (options == null) return null;

    // Resolve the app-start screen name during trace enrichment, not trace
    // creation. Its route is captured only at the first valid frame.
    return switch (options.traceLifecycle) {
      SentryTraceLifecycle.static => StaticAppStartTrace.tryCreate(
          hub: _hub,
          data: data,
          startScreenNameProvider: _resolveStartScreenName,
        ),
      SentryTraceLifecycle.stream => StreamingAppStartTrace.tryCreate(
          hub: _hub,
          data: data,
          startScreenNameProvider: _resolveStartScreenName,
        ),
    };
  }

  String _resolveStartScreenName() => resolveRouteDisplayName(_startScreenName);

  void _prepareTimeToDisplay(DateTime? startTimestamp) {
    final options = _flutterOptions;
    final resolvedStartTimestamp = startTimestamp ??
        SentryFlutter.sentrySetupStartTime ??
        options?.clock();
    if (options == null || resolvedStartTimestamp == null) return;

    switch (options.traceLifecycle) {
      case SentryTraceLifecycle.static:
        options.timeToDisplayTracker.prepareInitialDisplay(
          resolvedStartTimestamp,
        );
        _cancelPreparedDisplay = options.timeToDisplayTracker.clear;
      case SentryTraceLifecycle.stream:
        options.timeToDisplayTrackerV2.prepareAppStart(
          startTimestamp: resolvedStartTimestamp,
        );
        _cancelPreparedDisplay =
            options.timeToDisplayTrackerV2.cancelCurrentRoute;
    }
  }

  void _recordFirstFrame() {
    void callback(List<FrameTiming> timings) async {
      if (_closed || timings.isEmpty) return;

      final endTimestamp = DateTime.fromMicrosecondsSinceEpoch(
        timings.first.timestampInMicroseconds(FramePhase.rasterFinishWallTime),
      );

      _removeTimingsCallback();

      try {
        if (_closed) {
          return;
        }

        // Freeze the launch screen during first frame before enrichment;
        // the user may navigate away before the app-start span finishes.
        _startScreenName ??= SentryNavigatorObserver.currentRouteName;

        _trace?.recordFirstFrame(endTimestamp);

        // Keep display tracking last because TTFD may wait for its timeout.
        final options = _flutterOptions;
        if (options != null) {
          switch (options.traceLifecycle) {
            case SentryTraceLifecycle.static:
              await options.timeToDisplayTracker.recordInitialDisplay(
                endTimestamp,
              );
            case SentryTraceLifecycle.stream:
              options.timeToDisplayTrackerV2.trackAppStart(
                ttidEndTimestamp: endTimestamp,
              );
          }
        }
      } catch (error, stackTrace) {
        internalLogger.error(
          'Failed to record standalone app-start first frame',
          error: error,
          stackTrace: stackTrace,
        );
        if (_flutterOptions?.automatedTestMode ?? false) {
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
    await _trace?.close();
    _cancelPreparedDisplay?.call();
    _cancelPreparedDisplay = null;
    _trace = null;
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
