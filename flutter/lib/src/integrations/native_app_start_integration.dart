import 'package:meta/meta.dart';

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

  /// This timestamp marks the end of app startup. Either set automatically when
  /// [SentryFlutterOptions.autoAppStart] is true, or by calling
  /// [SentryFlutter.setAppStartEnd]
  @internal
  DateTime? appStartEnd;

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    _frameCallbackHandler.addPostFrameCallback((timeStamp) async {
      try {
        await _nativeAppStartHandler.call(hub, options, appStartEnd: appStartEnd);
      } catch (exception, stackTrace) {
        options.logger(
          SentryLevel.error,
          'Error while capturing native app start',
          exception: exception,
          stackTrace: stackTrace,
        );
      }
    });
    options.sdk.addIntegration('nativeAppStartIntegration');
  }
}
