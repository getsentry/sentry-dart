// ignore_for_file: invalid_use_of_internal_member

import 'dart:ui';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../frame_callback_handler.dart';
import 'native_app_start_handler.dart';

/// V2 native app-start integration that computes app start end on first frame
/// and ends TTID via the display timing controller. Native spans and
/// measurements are still handled by [NativeAppStartHandler].
@internal
class NativeAppStartIntegrationV2 extends Integration<SentryFlutterOptions> {
  NativeAppStartIntegrationV2(
    this._frameCallbackHandler,
    this._nativeAppStartHandler,
  );

  static const integrationName = 'NativeAppStartV2';

  final FrameCallbackHandler _frameCallbackHandler;
  final NativeAppStartHandler _nativeAppStartHandler;

  bool _allowProcessing = true;

  @override
  void call(Hub hub, SentryFlutterOptions options) async {
    if (!options.isTracingEnabled()) {
      options.log(SentryLevel.info,
          'Skipping $integrationName integration because tracing is disabled.');
      return;
    }
    if (!options.experimentalUseDisplayTimingV2) {
      return;
    }

    // Start app display timing via controller
    final handle = options.displayTiming.startApp(
      name: 'root /',
      now: options.clock(),
    );

    void timingsCallback(List<FrameTiming> timings) async {
      if (!_allowProcessing) {
        return;
      }
      _allowProcessing = false;

      try {
        final appStartEnd = DateTime.fromMicrosecondsSinceEpoch(
          timings.first.timestampInMicroseconds(
            FramePhase.rasterFinishWallTime,
          ),
        );

        // End TTID using V2 controller
        handle.endTtid(appStartEnd);

        // Reuse existing native handler for spans/measurements
        final context = SentryTransactionContext(
          'root /',
          SentrySpanOperations.uiLoad,
          origin: SentryTraceOrigins.autoUiTimeToDisplay,
        );

        await _nativeAppStartHandler.call(
          hub,
          options,
          context: context,
          appStartEnd: appStartEnd,
        );
      } catch (exception, stackTrace) {
        options.log(
          SentryLevel.error,
          'Error while capturing native app start (V2)',
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
