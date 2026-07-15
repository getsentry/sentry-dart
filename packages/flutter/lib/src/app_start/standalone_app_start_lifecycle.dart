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
  Future<void> start(Hub hub, SentryFlutterOptions options);

  Future<void> close();
}

/// Owns standalone app-start tracing from native timing through first display.
@internal
final class DefaultStandaloneAppStartLifecycle
    implements StandaloneAppStartLifecycle {
  final FrameCallbackHandler _frameCallbackHandler;
  final SentryNativeBinding _native;

  TimingsCallback? _firstFrameCallback;
  SentryFlutterOptions? _options;
  AppStartTrace? _trace;
  String? _capturedAppStartScreenName;
  bool _closed = false;
  bool _displayPrepared = false;

  DefaultStandaloneAppStartLifecycle(this._frameCallbackHandler, this._native);

  @override
  Future<void> start(Hub hub, SentryFlutterOptions options) async {
    if (_closed) return;
    _options = options;

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

    if (_closed) return;

    final fallbackStart = SentryFlutter.sentrySetupStartTime ?? options.clock();
    _prepareInitialDisplay(
      options,
      data?.processStartTimestamp ?? fallbackStart,
    );
    _displayPrepared = true;

    if (data != null) {
      _trace = switch (options.traceLifecycle) {
        SentryTraceLifecycle.static => StaticAppStartTrace.tryCreate(
            hub: hub,
            data: data,
            onCompleted: () => _trace = null,
            appStartScreenNameProvider: _provideAppStartScreenName,
          ),
        SentryTraceLifecycle.stream => StreamingAppStartTrace.tryCreate(
            hub: hub,
            data: data,
            onCompleted: () => _trace = null,
            appStartScreenNameProvider: _provideAppStartScreenName,
          ),
      };
    }

    _installFirstFrameCallback(options);
  }

  String _resolveAppStartScreenName() {
    final routeName = SentryNavigatorObserver.currentRouteName;
    return routeName == null || routeName.isEmpty ? 'root /' : routeName;
  }

  String _provideAppStartScreenName() =>
      _capturedAppStartScreenName ?? _resolveAppStartScreenName();

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

  void _installFirstFrameCallback(SentryFlutterOptions options) {
    void callback(List<FrameTiming> timings) async {
      if (timings.isEmpty) return;

      final endTimestamp = DateTime.fromMicrosecondsSinceEpoch(
        timings.first.timestampInMicroseconds(FramePhase.rasterFinishWallTime),
      );

      _firstFrameCallback = null;
      _frameCallbackHandler.removeTimingsCallback(callback);

      try {
        if (_trace != null) {
          _capturedAppStartScreenName ??= _resolveAppStartScreenName();
        }

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

        _trace?.recordNaturalEnd(endTimestamp);
      } catch (error, stackTrace) {
        internalLogger.error(
          'Failed to record standalone app-start first frame',
          error: error,
          stackTrace: stackTrace,
        );
        if (options.automatedTestMode) {
          rethrow;
        }
      } finally {
        _displayPrepared = false;
      }
    }

    _firstFrameCallback = callback;
    _frameCallbackHandler.addTimingsCallback(callback);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;

    if (_firstFrameCallback != null) {
      _frameCallbackHandler.removeTimingsCallback(_firstFrameCallback!);
      _firstFrameCallback = null;
    }

    try {
      await _trace?.close();
    } finally {
      final options = _options;
      _trace = null;
      _options = null;
      _capturedAppStartScreenName = null;

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
