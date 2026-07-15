// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'dart:ui';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../frame_callback_handler.dart';
import '../native/sentry_native_binding.dart';
import '../utils/internal_logger.dart';
import 'app_start_data.dart';
import 'app_start_trace.dart';
import 'static_app_start_trace.dart';
import 'streaming_app_start_trace.dart';

/// Controls standalone app-start tracing from SDK start through shutdown.
@internal
abstract interface class StandaloneAppStartLifecycle {
  Future<void> start();

  Future<void> close();
}

/// Owns standalone app-start tracing from native timing through first display.
@internal
final class DefaultStandaloneAppStartLifecycle
    implements StandaloneAppStartLifecycle {
  final Hub _hub;
  final FrameCallbackHandler _frameCallbackHandler;
  final SentryNativeBinding _native;

  static const _defaultStartScreenName = 'root /';

  AppStartTrace? _trace;
  String? _startScreenName;

  DefaultStandaloneAppStartLifecycle({
    Hub? hub,
    FrameCallbackHandler? frameCallbackHandler,
    required SentryNativeBinding native,
  }) : _hub = hub ?? HubAdapter(),
       _frameCallbackHandler =
           frameCallbackHandler ?? DefaultFrameCallbackHandler(),
       _native = native;

  SentryFlutterOptions get _options => _hub.options as SentryFlutterOptions;

  @override
  Future<void> start() async {
    AppStartData? data;
    try {
      final nativeAppStart = await _native.fetchNativeAppStart();
      final setupTimestamp = SentryFlutter.sentrySetupStartTime;
      if (nativeAppStart != null && setupTimestamp != null) {
        data = AppStartData.tryParse(
          nativeAppStart,
          sentrySetupTimestamp: setupTimestamp,
          // Eager parse: only trust timestamps through setup. First frame
          // is the measurement end later, not part of this ceiling.
          validUntil: setupTimestamp,
        );
      }
    } catch (error, stackTrace) {
      internalLogger.error(
        'Failed to fetch standalone app-start timing',
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (data == null) {
      internalLogger.info(
        'Skipping standalone app start: native timing unavailable or invalid',
      );
      return;
    }

    final trace = _createAppStartTrace(data);
    if (trace == null) {
      internalLogger.info(
        'Skipping standalone app start: trace was not created',
      );
      return;
    }

    _trace = trace;
    _prepareTimeToDisplay(data.processStartTimestamp);
    _finishOnFirstFrame();
  }

  AppStartTrace? _createAppStartTrace(AppStartData data) {
    String _resolvedStartScreenName() {
      final name = _startScreenName;
      return name == null || name.isEmpty ? _defaultStartScreenName : name;
    }

    return switch (_options.traceLifecycle) {
      SentryTraceLifecycle.static => StaticAppStartTrace.tryCreate(
        hub: _hub,
        data: data,
        startScreenName: _resolvedStartScreenName,
      ),
      SentryTraceLifecycle.stream => StreamingAppStartTrace.tryCreate(
        hub: _hub,
        data: data,
        startScreenName: _resolvedStartScreenName,
      ),
    };
  }

  void _prepareTimeToDisplay(DateTime startTimestamp) {
    switch (_options.traceLifecycle) {
      case SentryTraceLifecycle.static:
        _options.timeToDisplayTracker.prepareInitialDisplay(startTimestamp);
      case SentryTraceLifecycle.stream:
        _options.timeToDisplayTrackerV2.prepareAppStart(
          startTimestamp: startTimestamp,
        );
    }
  }

  void _finishOnFirstFrame() {
    void callback(List<FrameTiming> timings) async {
      if (timings.isEmpty) return;

      final endTimestamp = DateTime.fromMicrosecondsSinceEpoch(
        timings.first.timestampInMicroseconds(FramePhase.rasterFinishWallTime),
      );

      // Remove the callback directly after to avoid being called again.
      _frameCallbackHandler.removeTimingsCallback(callback);

      // Closed or never installed.
      if (_trace == null) return;

      try {
        // Freeze the launch screen during first frame before enrichment;
        // the user may navigate away before the app-start span finishes.
        _startScreenName ??= SentryNavigatorObserver.currentRouteName;

        switch (_options.traceLifecycle) {
          case SentryTraceLifecycle.static:
            await _options.timeToDisplayTracker.recordInitialDisplay(
              endTimestamp,
            );
          case SentryTraceLifecycle.stream:
            _options.timeToDisplayTrackerV2.trackAppStart(
              ttidEndTimestamp: endTimestamp,
            );
        }

        _trace?.recordNaturalEnd(endTimestamp);
      } catch (error, stackTrace) {
        internalLogger.error(
          'Failed to record standalone app-start first frame',
          error: error,
          stackTrace: stackTrace,
        );
        if (_options.automatedTestMode) {
          rethrow;
        }
      }
    }

    _frameCallbackHandler.addTimingsCallback(callback);
  }

  @override
  Future<void> close() async {
    await _trace?.close();
    switch (_options.traceLifecycle) {
      case SentryTraceLifecycle.static:
        _options.timeToDisplayTracker.clear();
      case SentryTraceLifecycle.stream:
        _options.timeToDisplayTrackerV2.cancelCurrentRoute();
    }
    _trace = null;
    _startScreenName = null;
  }
}
