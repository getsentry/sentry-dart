import 'dart:async';

import 'package:sentry/sentry.dart';

import '../../sentry_flutter.dart';
import '../integrations/app_start/app_start_tracker.dart';

/// EventProcessor that enriches [SentryTransaction] objects with app start
/// measurement.
class NativeAppStartEventProcessor implements EventProcessor {
  final AppStartTracker? _appStartTracker;

  NativeAppStartEventProcessor({
    AppStartTracker? appStartTracker,
  }) : _appStartTracker = appStartTracker ?? AppStartTracker();

  bool didAddAppStartMeasurement = false;

  @override
  Future<SentryEvent?> apply(SentryEvent event, {Hint? hint}) async {
    if (!didAddAppStartMeasurement || event is! SentryTransaction) {
      return event;
    }

    final appStartInfo = await _appStartTracker?.getAppStartInfo();
    final measurement = appStartInfo?.measurement;

    if (measurement != null) {
      event.measurements[measurement.name] = measurement;
      didAddAppStartMeasurement = true;
    }
    return event;
  }
}

