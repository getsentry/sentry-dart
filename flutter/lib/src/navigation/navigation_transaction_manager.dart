import '../../sentry_flutter.dart';
import '../native/sentry_native.dart';

class NavigationTransactionManager {
  final Hub _hub;
  final SentryNative? _native;
  final Duration _autoFinishAfter;

  NavigationTransactionManager(this._hub, this._native, this._autoFinishAfter);

  ISentrySpan startTransaction(String routeName, DateTime startTime) {
    final transactionContext = SentryTransactionContext(
      routeName,
      'ui.load',
      transactionNameSource: SentryTransactionNameSource.component,
      origin: SentryTraceOrigins.autoNavigationRouteObserver,
    );

    return _hub.startTransactionWithContext(
      transactionContext,
      waitForChildren: true,
      autoFinishAfter: _autoFinishAfter,
      trimEnd: true,
      startTimestamp: startTime,
      bindToScope: true,
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
      },
    );
  }
}
