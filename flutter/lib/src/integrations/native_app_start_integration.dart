import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import '../../sentry_flutter.dart';
import '../sentry_flutter_options.dart';
import '../native/sentry_native.dart';
import '../event_processor/native_app_start_event_processor.dart';
import 'app_start/app_start_tracker.dart';

/// Integration which handles communication with native frameworks in order to
/// enrich [SentryTransaction] objects with app start data for mobile vitals.
class NativeAppStartIntegration extends Integration<SentryFlutterOptions> {
  NativeAppStartIntegration(this._native, this._schedulerBindingProvider,
      {AppStartTracker? appStartTracker})
      : _appStartTracker = appStartTracker ?? AppStartTracker();

  final SentryNative _native;
  final SchedulerBindingProvider _schedulerBindingProvider;
  final AppStartTracker? _appStartTracker;

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
          final appStartEnd = options.clock();
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
              _appStartTracker?.setAppStartInfo(null);
              return;
            }

            final appStartInfo = AppStartInfo(
              DateTime.fromMillisecondsSinceEpoch(
                  nativeAppStart.appStartTime.toInt()),
              appStartEnd,
              measurement,
            );

            _appStartTracker?.setAppStartInfo(appStartInfo);
          } else {
            _appStartTracker?.setAppStartInfo(null);
          }
        });
      }
    }

    options.addEventProcessor(
        NativeAppStartEventProcessor(appStartTracker: _appStartTracker));

    options.sdk.addIntegration('nativeAppStartIntegration');
  }
}

/// Used to provide scheduler binding at call time.
typedef SchedulerBindingProvider = SchedulerBinding? Function();
