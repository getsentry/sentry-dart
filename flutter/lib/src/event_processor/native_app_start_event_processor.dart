import 'dart:async';

import 'package:sentry/sentry.dart';

import '../integrations/app_start/app_start_tracker.dart';
import '../integrations/integrations.dart';
import '../native/sentry_native.dart';

/// EventProcessor that enriches [SentryTransaction] objects with app start
/// measurement.
class NativeAppStartEventProcessor implements EventProcessor {
  /// We filter out App starts more than 60s
  static const _maxAppStartMillis = 60000;

  final AppStartTracker? _appStartTracker;

  NativeAppStartEventProcessor({
    AppStartTracker? appStartTracker,
  }) : _appStartTracker = appStartTracker ?? AppStartTracker();

  bool didAddAppStartMeasurement = false;

  @override
  Future<SentryEvent?> apply(SentryEvent event, {Hint? hint}) async {
    if (didAddAppStartMeasurement || event is! SentryTransaction) {
      return event;
    }

    final appStartInfo = await _appStartTracker?.getAppStartInfo();
    final measurement = appStartInfo?.measurement;

    if (measurement != null &&
        measurement.value.toInt() <= _maxAppStartMillis) {
      event.measurements[measurement.name] = measurement;
      didAddAppStartMeasurement = true;
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
