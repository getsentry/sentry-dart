import 'dart:async';

import 'package:sentry/sentry.dart';

import '../sentry_native.dart';
import '../sentry_native_channel.dart';

/// EventProcessor that enriches [SentryTransaction] objects with app start
/// measurement.
class NativeAppStartEventProcessor extends EventProcessor {
  NativeAppStartEventProcessor(
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
