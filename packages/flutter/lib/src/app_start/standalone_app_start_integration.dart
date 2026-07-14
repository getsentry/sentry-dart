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

/// Wires native app-start timing and Flutter's first frame to display and
/// standalone app-start tracing.
final class StandaloneAppStartIntegration
    extends Integration<SentryFlutterOptions> {
  StandaloneAppStartIntegration(this._frameCallbackHandler, this._native);

  @internal
  static const integrationName = 'NativeAppStart';

  final FrameCallbackHandler _frameCallbackHandler;
  final SentryNativeBinding _native;

  TimingsCallback? _firstFrameCallback;
  SentryFlutterOptions? _options;
  AppStartTrace? _trace;
  bool _closed = false;
  bool _displayPrepared = false;

  @override
  Future<void> call(Hub hub, SentryFlutterOptions options) async {
    if (_closed || _options != null) return;
    _options = options;

    if (!options.isTracingEnabled()) {
      internalLogger.info(
        'Skipping $integrationName integration because tracing is disabled.',
      );
      return;
    }

    if (!options.enableStandaloneAppStartTracing) return;

    options.sdk.addIntegration(integrationName);
    options.sdk.addFeature(SentryFeatures.standaloneAppStartTracing);
    if (!options.platform.isAndroid && !options.platform.isIOS) return;

    AppStartData? data;
    try {
      final nativeAppStart = await _native.fetchNativeAppStart();
      final setupTimestamp = SentryFlutter.sentrySetupStartTime;
      if (nativeAppStart != null && setupTimestamp != null) {
        data = parseStandaloneAppStart(
          nativeAppStart,
          sentrySetupTimestamp: setupTimestamp,
          snapshotTimestamp: options.clock(),
        );
      }
    } catch (error, stackTrace) {
      internalLogger.error(
        'Failed to fetch standalone app-start timing',
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (_closed || !identical(_options, options)) return;

    final fallbackStart = SentryFlutter.sentrySetupStartTime ?? options.clock();
    _prepareInitialDisplay(
        options, data?.processStartTimestamp ?? fallbackStart);
    _displayPrepared = true;
    final initialScreenName = _memoizedInitialScreenName();

    if (data != null) {
      var completedBeforePublication = false;
      AppStartTrace? trace;
      void onCompleted() {
        completedBeforePublication = true;
        if (identical(_trace, trace)) {
          _trace = null;
        }
      }

      try {
        trace = switch (options.traceLifecycle) {
          SentryTraceLifecycle.static => StaticAppStartTrace.tryCreate(
              hub: hub,
              data: data,
              onCompleted: onCompleted,
              initialScreenName: initialScreenName,
            ),
          SentryTraceLifecycle.stream => StreamingAppStartTrace.tryCreate(
              hub: hub,
              data: data,
              onCompleted: onCompleted,
              initialScreenName: initialScreenName,
            ),
        };
        if (trace != null && !completedBeforePublication && !_closed) {
          _trace = trace;
        } else {
          await trace?.close();
        }
      } catch (error, stackTrace) {
        internalLogger.error(
          'Failed to install standalone app-start trace',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    if (_closed || !identical(_options, options)) return;
    _installStandaloneFirstFrame(
      options,
      initialScreenName: initialScreenName,
      minimumEndTimestamp: data?.sentrySetupTimestamp ?? fallbackStart,
    );
  }

  void _prepareInitialDisplay(
    SentryFlutterOptions options,
    DateTime startTimestamp,
  ) {
    switch (options.traceLifecycle) {
      case SentryTraceLifecycle.static:
        options.timeToDisplayTracker.prepareInitialDisplay(startTimestamp);
      case SentryTraceLifecycle.stream:
        options.timeToDisplayTrackerV2.prepareAppStart(
          startTimestamp: startTimestamp,
        );
    }
  }

  void _installStandaloneFirstFrame(
    SentryFlutterOptions options, {
    required String Function() initialScreenName,
    required DateTime minimumEndTimestamp,
  }) {
    void callback(List<FrameTiming> timings) async {
      if (!identical(_firstFrameCallback, callback)) return;
      if (timings.isEmpty) return;

      final endTimestamp = DateTime.fromMicrosecondsSinceEpoch(
        timings.first.timestampInMicroseconds(
          FramePhase.rasterFinishWallTime,
        ),
      );
      if (endTimestamp.isBefore(minimumEndTimestamp)) return;

      _firstFrameCallback = null;
      _frameCallbackHandler.removeTimingsCallback(callback);
      Object? firstError;
      StackTrace? firstStackTrace;

      try {
        initialScreenName();
      } catch (error, stackTrace) {
        firstError = error;
        firstStackTrace = stackTrace;
      }

      try {
        switch (options.traceLifecycle) {
          case SentryTraceLifecycle.static:
            await options.timeToDisplayTracker
                .recordInitialDisplay(endTimestamp);
          case SentryTraceLifecycle.stream:
            options.timeToDisplayTrackerV2.trackAppStart(
              ttidEndTimestamp: endTimestamp,
            );
        }
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
        internalLogger.error(
          'Failed to record initial display',
          error: error,
          stackTrace: stackTrace,
        );
      } finally {
        _displayPrepared = false;
      }

      try {
        _trace?.recordNaturalEnd(endTimestamp);
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
        internalLogger.error(
          'Failed to record standalone app-start natural end',
          error: error,
          stackTrace: stackTrace,
        );
      }

      if (firstError != null && options.automatedTestMode) {
        Error.throwWithStackTrace(firstError, firstStackTrace!);
      }
    }

    _firstFrameCallback = callback;
    _frameCallbackHandler.addTimingsCallback(callback);
  }

  String Function() _memoizedInitialScreenName() {
    String? value;
    return () {
      final frozen = value;
      if (frozen != null) return frozen;
      try {
        final routeName = SentryNavigatorObserver.currentRouteName;
        value =
            routeName != null && routeName.isNotEmpty ? routeName : 'root /';
      } catch (error, stackTrace) {
        internalLogger.warning(
          'Failed to resolve the initial app-start screen',
          error: error,
          stackTrace: stackTrace,
        );
        value = 'root /';
      }
      return value!;
    };
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final callback = _firstFrameCallback;
    _firstFrameCallback = null;
    final options = _options;
    final trace = _trace;
    _trace = null;
    _options = null;

    if (callback != null) {
      _frameCallbackHandler.removeTimingsCallback(callback);
    }
    try {
      await trace?.close();
    } finally {
      if (_displayPrepared && options != null) {
        switch (options.traceLifecycle) {
          case SentryTraceLifecycle.static:
            options.timeToDisplayTracker.clear();
          case SentryTraceLifecycle.stream:
            options.timeToDisplayTrackerV2.cancelCurrentRoute();
        }
      }
    }
  }
}
