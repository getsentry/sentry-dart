import 'dart:async';

import '../../sentry_flutter.dart';
import '../integrations/integrations.dart';
import '../native/sentry_native.dart';

/// EventProcessor that enriches [SentryTransaction] objects with app start
/// measurement.
class NativeAppStartEventProcessor implements EventProcessor {
  final SentryNative _native;
  final Hub _hub;

  NativeAppStartEventProcessor(this._native, this._hub);

  @override
  Future<SentryEvent?> apply(SentryEvent event, {Hint? hint}) async {
    // ignore: invalid_use_of_internal_member
    final options = _hub.options;
    if (_native.didAddAppStartMeasurement ||
        event is! SentryTransaction ||
        options is! SentryFlutterOptions) {
      return event;
    }

    final appStartInfo = await NativeAppStartIntegration.getAppStartInfo();

    final appStartEnd = _native.appStartEnd;
    if (!options.autoAppStart) {
      if (appStartEnd != null) {
        appStartInfo?.end = appStartEnd;
      } else {
        // If autoAppStart is disabled and appStartEnd is not set, we can't add app starts
        return event;
      }
    }

    final measurement = appStartInfo?.toMeasurement();

    if (measurement != null) {
      event.measurements[measurement.name] = measurement;
      _native.didAddAppStartMeasurement = true;
    }
    return event;
  }
}
