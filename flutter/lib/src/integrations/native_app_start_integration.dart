import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import '../../sentry_flutter.dart';
import '../sentry_flutter_options.dart';
import '../native/sentry_native.dart';
import '../event_processor/native_app_start_event_processor.dart';

/// Integration which handles communication with native frameworks in order to
/// enrich [SentryTransaction] objects with app start data for mobile vitals.
class NativeAppStartIntegration extends Integration<SentryFlutterOptions> {
  NativeAppStartIntegration(this._native, this._schedulerBindingProvider);

  final SentryNative _native;
  final SchedulerBindingProvider _schedulerBindingProvider;

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    if (options.autoAppStart) {
      final schedulerBinding = _schedulerBindingProvider();
      if (schedulerBinding == null) {
        options.logger(SentryLevel.debug,
            'Scheduler binding is null. Can\'t auto detect app start time.');
      } else {
        schedulerBinding.addPostFrameCallback((timeStamp) async {
          final appStartEnd = options.clock();
          // ignore: invalid_use_of_internal_member
          _native.appStartEnd = appStartEnd;

          if (!_native.didFetchAppStart) {
            final nativeAppStart = await _native.fetchNativeAppStart();
            final measurement = nativeAppStart?.toMeasurement(appStartEnd!);

            // We filter out app start more than 60s.
            // This could be due to many different reasons.
            // If you do the manual init and init the SDK too late and it does not
            // compute the app start end in the very first Screen.
            // If the process starts but the App isn't in the foreground.
            // If the system forked the process earlier to accelerate the app start.
            // And some unknown reasons that could not be reproduced.
            // We've seen app starts with hours, days and even months.
            if (nativeAppStart == null ||
                measurement == null ||
                measurement.value >= 60000) {
              AppStartTracker().setAppStartInfo(null);
              return;
            }

            final appStartInfo = AppStartInfo(
              DateTime.fromMillisecondsSinceEpoch(
                  nativeAppStart.appStartTime.toInt()),
              appStartEnd,
              measurement,
            );

            AppStartTracker().setAppStartInfo(appStartInfo);
          } else {
            AppStartTracker().setAppStartInfo(null);
          }
        });
      }
    }

    options.addEventProcessor(NativeAppStartEventProcessor(_native));

    options.sdk.addIntegration('nativeAppStartIntegration');
  }
}

/// Used to provide scheduler binding at call time.
typedef SchedulerBindingProvider = SchedulerBinding? Function();

@internal
class AppStartInfo {
  final DateTime start;
  final DateTime end;
  final SentryMeasurement measurement;

  AppStartInfo(this.start, this.end, this.measurement);
}

@internal
class AppStartTracker {
  static final AppStartTracker _instance = AppStartTracker._internal();

  factory AppStartTracker() => _instance;

  AppStartInfo? _appStartInfo;

  AppStartInfo? get appStartInfo => _appStartInfo;
  Function(AppStartInfo?)? _callback;

  AppStartTracker._internal();

  void setAppStartInfo(AppStartInfo? appStartInfo) {
    _appStartInfo = appStartInfo;
    _notifyObserver();
  }

  void onAppStartComplete(Function(AppStartInfo?) callback) {
    _callback = callback;
    _callback?.call(_appStartInfo);
  }

  void _notifyObserver() {
    _callback?.call(_appStartInfo);
  }
}
