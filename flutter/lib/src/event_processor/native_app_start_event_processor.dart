import 'dart:async';

import 'package:sentry/sentry.dart';

import '../integrations/integrations.dart';

/// EventProcessor that enriches [SentryTransaction] objects with app start
/// measurement.
class NativeAppStartEventProcessor implements EventProcessor {
  NativeAppStartEventProcessor();

  // We want the app start measurement to only be added once to the first transaction
  bool _didAddAppStartMeasurement = false;

  @override
  Future<SentryEvent?> apply(SentryEvent event, {Hint? hint}) async {
    if (_didAddAppStartMeasurement || event is! SentryTransaction) {
      return event;
    }

    final appStartInfo = await NativeAppStartIntegration.getAppStartInfo();
    final measurement = appStartInfo?.toMeasurement();

    if (measurement != null) {
      event.measurements[measurement.name] = measurement;
      _didAddAppStartMeasurement = true;
    }
    return event;
  }
}
