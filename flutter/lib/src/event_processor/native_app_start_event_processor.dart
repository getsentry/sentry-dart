import 'dart:async';
import 'package:meta/meta.dart';

import 'package:sentry/sentry.dart';

import '../sentry_native_state.dart';
import '../sentry_native_wrapper.dart';

/// EventProcessor that enriches [SentryTransaction] objects with app start
/// measurement.
@internal
class NativeAppStartEventProcessor extends EventProcessor {
  NativeAppStartEventProcessor(
    this._nativeWrapper,
    this._nativeState,
  );

  final SentryNativeWrapper _nativeWrapper;
  final SentryNativeState _nativeState;

  var _didFetchAppStart = false;

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, {hint}) async {
    final appStartEnd = _nativeState.appStartEnd;

    if (appStartEnd != null &&
        event is SentryTransaction &&
        !_didFetchAppStart) {
      _didFetchAppStart = true;

      final nativeAppStart = await _nativeWrapper.fetchNativeAppStart();
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
