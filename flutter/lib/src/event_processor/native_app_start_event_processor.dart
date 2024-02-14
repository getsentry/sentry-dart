import 'dart:async';

import 'package:sentry/sentry.dart';

import '../integrations/integrations.dart';
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
    final appStartInfo = AppStartTracker().appStartInfo;
    // TODO: only do this once per app start
    if (appStartInfo != null && event is SentryTransaction) {
      final measurement = appStartInfo.measurement;
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
