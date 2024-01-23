import 'dart:async';

import 'package:sentry/sentry.dart';

import '../native/sentry_native.dart';

/// EventProcessor that enriches [SentryTransaction] objects with app start
/// measurement.
class NativeAppStartEventProcessor implements EventProcessor {
  /// We filter out App starts more than 60s
  static const _maxAppStartMillis = 60000;

  NativeAppStartEventProcessor(
    this._native,
  );

  final SentryNative _native;

  @override
  Future<SentryEvent?> apply(SentryEvent event, {Hint? hint}) async {
    final appStartEnd = _native.appStartEnd;

    if (appStartEnd != null &&
        event is SentryTransaction &&
        !_native.didFetchAppStart) {
      final nativeAppStart = await _native.fetchNativeAppStart();
      if (nativeAppStart == null) {
        return event;
      }
      final measurement = nativeAppStart.toMeasurement(appStartEnd);
      // We filter out app start more than 60s.
      // This could be due to many different reasons.
      // If you do the manual init and init the SDK too late and it does not
      // compute the app start end in the very first Screen.
      // If the process starts but the App isn't in the foreground.
      // If the system forked the process earlier to accelerate the app start.
      // And some unknown reasons that could not be reproduced.
      // We've seen app starts with hours, days and even months.
      if (measurement.value >= _maxAppStartMillis) {
        return event;
      }
      event.measurements[measurement.name] = measurement;
    }
    return event;
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
