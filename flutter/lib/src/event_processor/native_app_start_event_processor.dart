import 'dart:async';

import 'package:sentry/sentry.dart';

import '../integrations/integrations.dart';
import '../native/sentry_native.dart';

/// EventProcessor that enriches [SentryTransaction] objects with app start
/// measurement.
class NativeAppStartEventProcessor implements EventProcessor {
  /// We filter out App starts more than 60s
  static const _maxAppStartMillis = 60000;

  final IAppStartTracker? _appStartTracker;

  NativeAppStartEventProcessor({
    IAppStartTracker? appStartTracker,
  }) : _appStartTracker = appStartTracker ?? AppStartTracker();

  bool didAddAppStartMeasurement = false;

  @override
  Future<SentryEvent?> apply(SentryEvent event, {Hint? hint}) async {
    final measurement = _appStartTracker?.appStartInfo?.measurement;
    // TODO: only do this once per app start
    if (!didAddAppStartMeasurement &&
        measurement != null &&
        measurement.value.toInt() <= _maxAppStartMillis &&
        event is SentryTransaction) {
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
