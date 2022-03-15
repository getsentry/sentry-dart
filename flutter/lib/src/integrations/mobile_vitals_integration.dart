import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:sentry/sentry.dart';

import '../sentry_flutter_options.dart';
import '../sentry_native_state.dart';
import '../sentry_native_wrapper.dart';
import '../event_processor/native_app_start_event_processor.dart';

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
          _nativeState.appStartEnd = DateTime.now().toUtc();
        });
      }
    }

    options.addEventProcessor(
        NativeAppStartEventProcessor(_nativeWrapper, _nativeState));

    options.sdk.addIntegration('mobileVitalsIntegration');
  }
}

/// Used to provide scheduler binding at call time.
typedef SchedulerBindingProvider = SchedulerBinding? Function();
