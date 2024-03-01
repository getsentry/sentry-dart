import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../frame_callback_handler.dart';
import '../native/sentry_native.dart';
import '../event_processor/native_app_start_event_processor.dart';

enum AppStartType { cold, warm }

class AppStartInfo {
  AppStartInfo(this.type, {required this.start, required this.end});

  final AppStartType type;
  final DateTime start;
  final DateTime end;

  SentryMeasurement toMeasurement() {
    final duration = end.difference(start);
    return type == AppStartType.cold
        ? SentryMeasurement.coldAppStart(duration)
        : SentryMeasurement.warmAppStart(duration);
  }
}

/// Integration which handles communication with native frameworks in order to
/// enrich [SentryTransaction] objects with app start data for mobile vitals.
class NativeAppStartIntegration extends Integration<SentryFlutterOptions> {
  NativeAppStartIntegration(this._native, this._schedulerBindingProvider);

  final SentryNative _native;
  final SchedulerBindingProvider _schedulerBindingProvider;

  /// We filter out App starts more than 60s
  static const _maxAppStartMillis = 60000;

  static Completer<AppStartInfo?> _appStartCompleter =
      Completer<AppStartInfo?>();
  static AppStartInfo? _appStartInfo;

  @internal
  static void setAppStartInfo(AppStartInfo? appStartInfo) {
    _appStartInfo = appStartInfo;
    _appStartCompleter.complete(appStartInfo);
  }

  @internal
  static Future<AppStartInfo?> getAppStartInfo() {
    if (_appStartInfo != null) {
      return Future.value(_appStartInfo);
    }
    return _appStartCompleter.future;
  }

  @internal
  static void clearAppStartInfo() {
    _appStartInfo = null;
    if (_appStartCompleter.isCompleted) {
      _appStartCompleter = Completer<AppStartInfo?>();
    }
  }

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    if (options.autoAppStart) {
      final schedulerBinding = _schedulerBindingProvider();
      if (schedulerBinding == null) {
        options.logger(SentryLevel.debug,
            'Scheduler binding is null. Can\'t auto detect app start time.');
      } else {
        schedulerBinding.addPostFrameCallback((timeStamp) async {
          // ignore: invalid_use_of_internal_member
          // We only assign the current time if it's not already set
          // this is useful in tests
          _native.appStartEnd ??= options.clock();
          final appStartEnd = _native.appStartEnd;

          if (_native.didFetchAppStart || appStartEnd == null) {
            setAppStartInfo(null);
            return;
          }

          final nativeAppStart = await _native.fetchNativeAppStart();

          if (nativeAppStart == null) {
            setAppStartInfo(null);
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
              nativeAppStart.isColdStart
                  ? AppStartType.cold
                  : AppStartType.warm,
              start: DateTime.fromMillisecondsSinceEpoch(
                  nativeAppStart.appStartTime.toInt()),
              end: appStartEnd);
          setAppStartInfo(appStartInfo);
        });
      }
    }

    options.addEventProcessor(NativeAppStartEventProcessor());

    options.sdk.addIntegration('nativeAppStartIntegration');
  }
}

/// Used to provide scheduler binding at call time.
typedef SchedulerBindingProvider = FrameCallbackHandler? Function();

