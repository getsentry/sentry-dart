import 'dart:async';
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

  final FrameCallbackHandler _frameCallbackHandler;
  final NativeAppStartHandler _nativeAppStartHandler;
  DateTime? _appStartEnd;

  /// This timestamp marks the end of app startup. Either set by calling
  /// [SentryFlutter.setAppStartEnd]. The [SentryFlutterOptions.autoAppStart]
  /// option needs to be false.
  @internal
  set appStartEnd(DateTime appStartEnd) {
    _appStartEnd = appStartEnd;
    if (!_appStartEndCompleter.isCompleted) {
      _appStartEndCompleter.complete();
    }
  }

  final Completer<void> _appStartEndCompleter = Completer<void>();

  @override
  void call(Hub hub, SentryFlutterOptions options) async {
    bool loadedAppStartEnd = false;
    bool isHandlingCallback = false;

    void timingsCallback(List<FrameTiming> timings) async {
      if (loadedAppStartEnd || isHandlingCallback) {
        return;
      }

      isHandlingCallback = true;

      try {
        DateTime? appStartEnd;
        if (options.autoAppStart) {
          // ignore: invalid_use_of_internal_member
          appStartEnd = DateTime.fromMicrosecondsSinceEpoch(timings.first
              .timestampInMicroseconds(FramePhase.rasterFinishWallTime));
        } else if (_appStartEnd == null) {
          await _appStartEndCompleter.future.timeout(
            const Duration(seconds: 10),
          );
          appStartEnd = _appStartEnd;
        } else {
          appStartEnd = null;
        }
        if (appStartEnd != null) {
          await _nativeAppStartHandler.call(
            hub,
            options,
            appStartEnd: appStartEnd,
          );
        }
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
        loadedAppStartEnd = true;
        isHandlingCallback = false;
        _frameCallbackHandler.removeTimingsCallback(timingsCallback);
      }
    }

    _frameCallbackHandler.addTimingsCallback(timingsCallback);
    options.sdk.addIntegration('nativeAppStartIntegration');
  }
}
