import 'package:flutter/scheduler.dart';
import 'package:sentry/sentry.dart';

import '../../sentry_flutter.dart';
import '../sentry_flutter_options.dart';
import '../native/sentry_native.dart';
import '../event_processor/native_app_start_event_processor.dart';

/// Integration which handles communication with native frameworks in order to
/// enrich [SentryTransaction] objects with app start data for mobile vitals.
class NativeAppStartIntegration extends Integration<SentryFlutterOptions> {
  NativeAppStartIntegration(this._native, this._schedulerBindingProvider);

  final SentryNative _native;
  final SchedulerBindingProvider _schedulerBindingProvider;

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    if (options.autoAppStart) {
      final schedulerBinding = _schedulerBindingProvider();
      if (schedulerBinding == null) {
        options.logger(SentryLevel.debug,
            'Scheduler binding is null. Can\'t auto detect app start time.');
      } else {
        schedulerBinding.addPostFrameCallback((timeStamp) async {
          // ignore: invalid_use_of_internal_member
          _native.appStartEnd = options.clock();

          final appStartEnd = _native.appStartEnd;

          if (_native.appStartEnd != null && !_native!.didFetchAppStart) {
            print('fetch app start');
            final nativeAppStart = await _native!.fetchNativeAppStart();
            if (nativeAppStart == null) {
              return;
            }
            final measurement = nativeAppStart.toMeasurement(appStartEnd!);
            // We filter out app start more than 60s.
            // This could be due to many different reasons.
            // If you do the manual init and init the SDK too late and it does not
            // compute the app start end in the very first Screen.
            // If the process starts but the App isn't in the foreground.
            // If the system forked the process earlier to accelerate the app start.
            // And some unknown reasons that could not be reproduced.
            // We've seen app starts with hours, days and even months.
            if (measurement.value >= 60000) {
              return;
            }

            final appStartDateTime = DateTime.fromMillisecondsSinceEpoch(
                nativeAppStart.appStartTime.toInt());

            final transactionContext2 = SentryTransactionContext(
              'root ("/")',
              'ui.load',
              transactionNameSource: SentryTransactionNameSource.component,
              // ignore: invalid_use_of_internal_member
              origin: SentryTraceOrigins.autoNavigationRouteObserver,
            );

            final transaction2 = hub.startTransactionWithContext(
                transactionContext2,
                waitForChildren: true,
                autoFinishAfter: Duration(seconds: 3),
                trimEnd: true,
                startTimestamp: appStartDateTime,
                onFinish: (transaction) async {
              final nativeFrames = await _native
                  ?.endNativeFramesCollection(transaction.context.traceId);
              if (nativeFrames != null) {
                final measurements = nativeFrames.toMeasurements();
                for (final item in measurements.entries) {
                  final measurement = item.value;
                  transaction.setMeasurement(
                    item.key,
                    measurement.value,
                    unit: measurement.unit,
                  );
                }
              }
            });

            final ttidSpan = transaction2.startChild('ui.load.initial_display', startTimestamp: appStartDateTime);
            await ttidSpan.finish(endTimestamp: appStartEnd);

            SentryNavigatorObserver.ttfdSpan = transaction2.startChild('ui.load.full_display', startTimestamp: appStartDateTime);

            print('end of the road');
          }
        });
      }
    }

    options.addEventProcessor(NativeAppStartEventProcessor(_native));

    options.sdk.addIntegration('nativeAppStartIntegration');
  }
}

/// Used to provide scheduler binding at call time.
typedef SchedulerBindingProvider = SchedulerBinding? Function();
