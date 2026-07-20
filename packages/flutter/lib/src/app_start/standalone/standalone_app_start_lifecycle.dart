// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'dart:ui';

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../frame_callback_handler.dart';
import '../../native/sentry_native_binding.dart';
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

  static const _defaultStartScreenName = 'root /';

  AppStartTrace? _trace;
  String? _startScreenName;

  SentryFlutterOptions? get _flutterOptions {
    final options = _hub.options;
    return options is SentryFlutterOptions ? options : null;
  }

  StandaloneAppStartLifecycle({
    Hub? hub,
    FrameCallbackHandler? frameCallbackHandler,
    required SentryNativeBinding native,
  }) : _hub = hub ?? HubAdapter(),
       _frameCallbackHandler =
           frameCallbackHandler ?? DefaultFrameCallbackHandler(),
       _native = native;

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

  String _resolveStartScreenName() {
    final name = _startScreenName;
    if (name == null || name.isEmpty || name == '/') {
      return _defaultStartScreenName;
    }
    return name;
  }

  void _prepareTimeToDisplay(DateTime startTimestamp) {
    final options = _flutterOptions;
    if (options == null) return;

    switch (options.traceLifecycle) {
      case SentryTraceLifecycle.static:
        options.timeToDisplayTracker.prepareInitialDisplay(startTimestamp);
      case SentryTraceLifecycle.stream:
        options.timeToDisplayTrackerV2.prepareAppStart(
          startTimestamp: startTimestamp,
        );
    }
  }

  void _recordFirstFrame() {
    void callback(List<FrameTiming> timings) async {
      if (timings.isEmpty) return;

      final endTimestamp = DateTime.fromMicrosecondsSinceEpoch(
        timings.first.timestampInMicroseconds(FramePhase.rasterFinishWallTime),
      );

      _frameCallbackHandler.removeTimingsCallback(callback);

      try {
        // Freeze the launch screen during first frame before enrichment;
        // the user may navigate away before the app-start span finishes.
        _startScreenName ??= SentryNavigatorObserver.currentRouteName;

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

        _trace?.recordFirstFrame(endTimestamp);
        _trace?.finish(endTimestamp);
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

    _frameCallbackHandler.addTimingsCallback(callback);
  }

  Future<void> close() async {
    await _trace?.close();
    final options = _flutterOptions;
    if (options != null) {
      switch (options.traceLifecycle) {
        case SentryTraceLifecycle.static:
          options.timeToDisplayTracker.clear();
        case SentryTraceLifecycle.stream:
          options.timeToDisplayTrackerV2.cancelCurrentRoute();
      }
    }
    _trace = null;
    _startScreenName = null;
  }
}
