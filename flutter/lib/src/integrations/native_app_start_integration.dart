import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../frame_callback_handler.dart';
import '../native/sentry_native.dart';
import '../event_processor/native_app_start_event_processor.dart';

/// Integration which handles communication with native frameworks in order to
/// enrich [SentryTransaction] objects with app start data for mobile vitals.
class NativeAppStartIntegration extends Integration<SentryFlutterOptions> {
  NativeAppStartIntegration(this._native, this._frameCallbackHandler);

  final SentryNative _native;
  final FrameCallbackHandler _frameCallbackHandler;

  /// We filter out App starts more than 60s
  static const _maxAppStartMillis = 60000;

  static Completer<AppStartInfo?> _appStartCompleter =
      Completer<AppStartInfo?>();
  static AppStartInfo? _appStartInfo;

  @internal
  static bool isIntegrationTest = false;

  @internal
  static void setAppStartInfo(AppStartInfo? appStartInfo) {
    _appStartInfo = appStartInfo;
    if (_appStartCompleter.isCompleted) {
      _appStartCompleter = Completer<AppStartInfo?>();
    }
    _appStartCompleter.complete(appStartInfo);
  }

  @internal
  static Future<AppStartInfo?> getAppStartInfo() {
    if (_appStartInfo != null) {
      return Future.value(_appStartInfo);
    }
    return _appStartCompleter.future;
  }

  @visibleForTesting
  static void clearAppStartInfo() {
    _appStartInfo = null;
    _appStartCompleter = Completer<AppStartInfo?>();
  }

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    if (isIntegrationTest) {
      final appStartInfo = AppStartInfo(AppStartType.cold,
          start: DateTime.now(),
          end: DateTime.now().add(const Duration(milliseconds: 100)));
      setAppStartInfo(appStartInfo);
      return;
    }

    if (options.autoAppStart) {
      _frameCallbackHandler.addPostFrameCallback((timeStamp) async {
        if (_native.didFetchAppStart) {
          return;
        }

        // We only assign the current time if it's not already set - this is useful in tests
        // ignore: invalid_use_of_internal_member
        _native.appStartEnd ??= options.clock();
        final appStartEnd = _native.appStartEnd;
        final nativeAppStart = await _native.fetchNativeAppStart();

        if (nativeAppStart == null || appStartEnd == null) {
          return;
        }

        final appStartDateTime = DateTime.fromMillisecondsSinceEpoch(
            nativeAppStart.appStartTime.toInt());
        final duration = appStartEnd.difference(appStartDateTime);

        // We filter out app start more than 60s.
        // This could be due to many different reasons.
        // If you do the manual init and init the SDK too late and it does not
        // compute the app start end in the very first Screen.
        // If the process starts but the App isn't in the foreground.
        // If the system forked the process earlier to accelerate the app start.
        // And some unknown reasons that could not be reproduced.
        // We've seen app starts with hours, days and even months.
        if (duration.inMilliseconds > _maxAppStartMillis) {
          setAppStartInfo(null);
          return;
        }

        final appStartInfo = AppStartInfo(
            nativeAppStart.isColdStart ? AppStartType.cold : AppStartType.warm,
            start: DateTime.fromMillisecondsSinceEpoch(
                nativeAppStart.appStartTime.toInt()),
            end: appStartEnd);
        setAppStartInfo(appStartInfo);
      });
    }

    options.addEventProcessor(NativeAppStartEventProcessor(_native));

    options.sdk.addIntegration('nativeAppStartIntegration');
  }
}

enum AppStartType { cold, warm }

class AppStartInfo {
  AppStartInfo(this.type, {required this.start, required this.end});

  final AppStartType type;
  final DateTime start;
  final DateTime end;
  Duration get duration => end.difference(start);

  SentryMeasurement toMeasurement() {
    return type == AppStartType.cold
        ? SentryMeasurement.coldAppStart(duration)
        : SentryMeasurement.warmAppStart(duration);
  }
}
