// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'dart:ui';

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../frame_callback_handler.dart';
import '../../navigation/root_route.dart';
import '../../utils/internal_logger.dart';
import 'native_app_start_handler.dart';
import 'native_app_start_handler_v2.dart';

/// Integration which calls [NativeAppStartHandler] or [NativeAppStartHandlerV2]
/// after [SchedulerBinding.instance.addPostFrameCallback] is called.
class NativeAppStartIntegration extends Integration<SentryFlutterOptions> {
  NativeAppStartIntegration(
    this._frameCallbackHandler,
    this._nativeAppStartHandler,
    this._nativeAppStartHandlerV2,
  );

  @internal
  static const integrationName = 'NativeAppStart';

  final FrameCallbackHandler _frameCallbackHandler;
  final NativeAppStartHandler _nativeAppStartHandler;
  final NativeAppStartHandlerV2 _nativeAppStartHandlerV2;

  bool _allowProcessing = true;

  /// Integrations are awaited by the SDK before `runApp`, so anything escaping
  /// here would leave the app unstarted. App-start tracing is never worth that.
  @override
  Future<void> call(Hub hub, SentryFlutterOptions options) async {
    try {
      _install(hub, options);
    } catch (exception, stackTrace) {
      internalLogger.error(
        'Error while installing $integrationName integration',
        error: exception,
        stackTrace: stackTrace,
      );
      if (options.automatedTestMode) {
        rethrow;
      }
    }
  }

  void _install(Hub hub, SentryFlutterOptions options) {
    if (options.usesStandaloneAppStart) return;

    if (!options.isTracingEnabled()) {
      internalLogger.info(
        'Skipping $integrationName integration because tracing is disabled.',
      );
      return;
    }

    // V1 path: Create context early so we have an id to reference for reporting full display
    SentryTransactionContext? context;
    if (options.traceLifecycle == SentryTraceLifecycle.static) {
      context = initialDisplayTransactionContext();
      options.timeToDisplayTracker.transactionId = context.spanId;
    }

    // V2 path: Create root idle span early so user spans in initState
    // can parent to it. Timestamps will be backdated when native data arrives.
    if (options.traceLifecycle == SentryTraceLifecycle.stream) {
      options.timeToDisplayTrackerV2.prepareAppStart();
    }

    void timingsCallback(List<FrameTiming> timings) async {
      if (!_allowProcessing) {
        return;
      }
      // Set immediately to prevent multiple executions
      // we only care about the first frame
      _allowProcessing = false;

      try {
        final appStartEnd = DateTime.fromMicrosecondsSinceEpoch(
          timings.first.timestampInMicroseconds(
            FramePhase.rasterFinishWallTime,
          ),
        );

        switch (options.traceLifecycle) {
          case SentryTraceLifecycle.stream:
            await _nativeAppStartHandlerV2.call(
              hub,
              options,
              appStartEnd: appStartEnd,
            );
          case SentryTraceLifecycle.static:
            if (context == null) {
              internalLogger.warning(
                'Skipping native app start integration because context is null',
              );
              return;
            }
            await _nativeAppStartHandler.call(
              hub,
              options,
              context: context,
              appStartEnd: appStartEnd,
            );
        }
      } catch (exception, stackTrace) {
        internalLogger.error(
          'Error while capturing native app start',
          error: exception,
          stackTrace: stackTrace,
        );
        if (options.automatedTestMode) {
          rethrow;
        }
      } finally {
        _frameCallbackHandler.removeTimingsCallback(timingsCallback);
      }
    }

    _frameCallbackHandler.addTimingsCallback(timingsCallback);
    options.sdk.addIntegration(integrationName);
  }
}
