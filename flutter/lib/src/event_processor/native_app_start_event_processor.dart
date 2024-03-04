import 'dart:async';

import 'package:sentry/sentry.dart';

import '../integrations/integrations.dart';
import '../native/sentry_native.dart';

/// EventProcessor that enriches [SentryTransaction] objects with app start
/// measurement.
class NativeAppStartEventProcessor implements EventProcessor {
  final SentryNative _native;

  NativeAppStartEventProcessor(this._native);

  @override
  Future<SentryEvent?> apply(SentryEvent event, {Hint? hint}) async {
    if (_native.didAddAppStartMeasurement || event is! SentryTransaction) {
      return event;
    }

    final appStartInfo = await NativeAppStartIntegration.getAppStartInfo();
    final measurement = appStartInfo?.toMeasurement();

    if (measurement != null) {
      event.measurements[measurement.name] = measurement;
      _native.setDidAddAppStartMeasurement(true);
    }
    return event;
  }
}
