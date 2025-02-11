import 'dart:ui';

import '../../sentry_flutter.dart';
import '../frame_callback_handler.dart';
import 'native_app_start_handler.dart';

/// Integration which calls [NativeAppStartHandler] after
/// [SchedulerBinding.instance.addPostFrameCallback] is called.
class NativeAppStartIntegration extends Integration<SentryFlutterOptions> {
  NativeAppStartIntegration(
      this._frameCallbackHandler, this._nativeAppStartHandler);

  final FrameCallbackHandler _frameCallbackHandler;
  final NativeAppStartHandler _nativeAppStartHandler;

  bool _allowProcessing = true;

  @override
  void call(Hub hub, SentryFlutterOptions options) async {
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
          appStartEnd: appStartEnd,
        );
      } catch (exception, stackTrace) {
        options.logger(
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
    options.sdk.addIntegration('nativeAppStartIntegration');
  }
}
