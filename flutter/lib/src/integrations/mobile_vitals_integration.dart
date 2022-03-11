import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:sentry/sentry.dart';

import '../sentry_flutter_options.dart';
import '../sentry_native.dart';
import '../sentry_native_wrapper.dart';

/// Integration which handles communication with native frameworks in order to
/// enrich [SentryTransaction] objects with data for mobile vitals.
class MobileVitalsIntegration extends Integration<SentryFlutterOptions> {
  MobileVitalsIntegration(this._native, this._schedulerBindingProvider);

  final SentryNative _native;
  final SchedulerBindingProvider _schedulerBindingProvider;

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    if (options.autoAppStart) {
      final schedulerBinding = _schedulerBindingProvider();
      if (schedulerBinding == null) {
        options.logger(SentryLevel.debug,
            'Scheduler binding is null. Can\'t auto detect app start time.');
      } else {
        schedulerBinding.addPostFrameCallback((timeStamp) {
          _native.appStartEnd = DateTime.now();
        });
      }
    }

    options.addEventProcessor(_NativeAppStartEventProcessor(_native));

    options.sdk.addIntegration('mobileVitalsIntegration');
  }
}

class _NativeAppStartEventProcessor extends EventProcessor {
  _NativeAppStartEventProcessor(
    this._native,
  );

  final SentryNative _native;

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, {hint}) async {
    final appStartEnd = _native.appStartEnd;

    if (appStartEnd != null &&
        event is SentryTransaction &&
        !_native.didFetchAppStart) {

      final nativeAppStart = await _native.fetchNativeAppStart();
      if (nativeAppStart == null) {
        return event;
      } else {
        final measurements = event.measurements ?? [];
        measurements.add(nativeAppStart.toMeasurement(appStartEnd));
        return event.copyWith(measurements: measurements);
      }
    } else {
      return event;
    }
  }
}

extension NativeAppStartMeasurement on NativeAppStart {
  SentryMeasurement toMeasurement(DateTime appStartEnd) {
    final appStartDateTime =
        DateTime.fromMillisecondsSinceEpoch(appStartTime.toInt());
    final duration = appStartEnd.difference(appStartDateTime);

    return isColdStart
        ? SentryMeasurement.coldAppStart(duration)
        : SentryMeasurement.warmAppStart(duration);
  }
}

/// Used to provide scheduler binding at call time.
typedef SchedulerBindingProvider = SchedulerBinding? Function();
