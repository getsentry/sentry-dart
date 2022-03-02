import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:sentry/sentry.dart';

import '../sentry_flutter_options.dart';
import '../sentry_native_wrapper.dart';

/// Integration which handles communication with native frameworks in order to
/// enrich [SentryTransaction] objects with data for mobile vitals.
class MobileVitalsIntegration extends Integration<SentryFlutterOptions> {
  MobileVitalsIntegration(this._nativeWrapper);

  final SentryNativeWrapper _nativeWrapper;

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    if (options.autoAppStart) {
      SchedulerBinding.instance?.addPostFrameCallback((timeStamp) {
        options.appStartFinish = DateTime.now();
      });
    }

    options.addEventProcessor(
        _NativeAppStartEventProcessor(_nativeWrapper, options));

    options.sdk.addIntegration('mobileVitalsIntegration');
  }
}

class _NativeAppStartEventProcessor extends EventProcessor {
  _NativeAppStartEventProcessor(this._nativeWrapper, this._options);

  final SentryNativeWrapper _nativeWrapper;
  final SentryFlutterOptions _options;

  var _didFetchAppStart = false;

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, {hint}) async {
    final appStartFinishTime = _options.appStartFinish;

    if (appStartFinishTime != null &&
        event is SentryTransaction &&
        !_didFetchAppStart) {
      _didFetchAppStart = true;

      final nativeAppStart = await _nativeWrapper.fetchNativeAppStart();
      if (nativeAppStart == null) {
        return event;
      } else {
        return event.copyWith(
            measurements: [nativeAppStart.toMeasurement(appStartFinishTime)]);
      }
    } else {
      return event;
    }
  }
}

extension NativeAppStartMeasurement on NativeAppStart {
  SentryMeasurement toMeasurement(DateTime appStartFinishTime) {
    final appStartDateTime =
        DateTime.fromMillisecondsSinceEpoch(appStartTime.toInt());
    final duration = appStartFinishTime.difference(appStartDateTime);

    return isColdStart
        ? SentryMeasurement.coldAppStart(duration)
        : SentryMeasurement.warmAppStart(duration);
  }
}
