import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:sentry/sentry.dart';

import '../sentry_flutter_options.dart';
import '../sentry_native_state.dart';
import '../sentry_native_wrapper.dart';

/// Integration which handles communication with native frameworks in order to
/// enrich [SentryTransaction] objects with data for mobile vitals.
class MobileVitalsIntegration extends Integration<SentryFlutterOptions> {
  MobileVitalsIntegration(
      this._nativeWrapper, this._nativeState, this._schedulerBindingProvider);

  final SentryNativeWrapper _nativeWrapper;
  final SentryNativeState _nativeState;
  final SchedulerBindingProvider _schedulerBindingProvider;

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    if (options.autoAppStart) {
      final schedulerBinding = _schedulerBindingProvider();
      if (schedulerBinding == null) {
        options.logger(SentryLevel.debug,
            'Scheduler binding is null. Can\'t auto detect app start time.');
      } else {
        schedulerBinding.addPostFrameCallback((timeStamp) {
          _nativeState.appStartEnd = DateTime.now();
        });
      }
    }

    options.addEventProcessor(
        _NativeAppStartEventProcessor(_nativeWrapper, _nativeState));

    options.sdk.addIntegration('mobileVitalsIntegration');
  }
}

class _NativeAppStartEventProcessor extends EventProcessor {
  _NativeAppStartEventProcessor(
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
        return event.copyWith(
            measurements: [nativeAppStart.toMeasurement(appStartEnd)]);
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

/// Used to provide scheduler binding at call time.
typedef SchedulerBindingProvider = SchedulerBinding? Function();
