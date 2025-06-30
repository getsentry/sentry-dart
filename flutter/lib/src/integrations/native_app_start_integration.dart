import 'dart:ui';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../frame_callback_handler.dart';
import 'native_app_start_handler.dart';

/// Integration which calls [NativeAppStartHandler] after
/// [SchedulerBinding.instance.addPostFrameCallback] is called.
class NativeAppStartIntegration extends Integration<SentryFlutterOptions> {
  NativeAppStartIntegration(
      this._frameCallbackHandler, this._nativeAppStartHandler);

  @internal
  static const integrationName = 'NativeAppStart';

  final FrameCallbackHandler _frameCallbackHandler;
  final NativeAppStartHandler _nativeAppStartHandler;

  bool _allowProcessing = true;

  @override
  void call(Hub hub, SentryFlutterOptions options) async {
    if (!options.isTracingEnabled()) {
      options.log(SentryLevel.info,
          '$integrationName integration is disabled. Tracing is not enabled.');
      return;
    }

    // Create context early so we have an id to refernce for reporting full display
    final context = SentryTransactionContext(
      'root /',
      // ignore: invalid_use_of_internal_member
      SentrySpanOperations.uiLoad,
    );
    options.timeToDisplayTracker.transactionId = context.spanId;

    void timingsCallback(List<FrameTiming> timings) async {
      if (!_allowProcessing) {
        return;
      }
      // Set immediately to prevent multiple executions
      // we only care about the first frame
      _allowProcessing = false;

      try {
        // ignore: invalid_use_of_internal_member
        final appStartEnd = DateTime.fromMicrosecondsSinceEpoch(timings.first
            .timestampInMicroseconds(FramePhase.rasterFinishWallTime));
        await _nativeAppStartHandler.call(
          hub,
          options,
          context: context,
          appStartEnd: appStartEnd,
        );
      } catch (exception, stackTrace) {
        options.log(
          SentryLevel.error,
          'Error while capturing native app start',
          exception: exception,
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
