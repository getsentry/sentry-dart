import 'package:meta/meta.dart';
import '../../sentry_flutter.dart';
import '../native/sentry_native.dart';

@internal
class TimeToDisplayTransactionHandler {
  final Hub? _hub;
  final bool? _enableAutoTransactions;
  final Duration? _autoFinishAfter;
  final SentryNative? _native;

  TimeToDisplayTransactionHandler({
    required Hub? hub,
    required bool? enableAutoTransactions,
    required Duration? autoFinishAfter,
  })  : _hub = hub ?? HubAdapter(),
        _enableAutoTransactions = enableAutoTransactions,
        _autoFinishAfter = autoFinishAfter,
        _native = SentryFlutter.native;

  @override
  Future<ISentrySpan?> startTransaction(String? routeName, Object? arguments,
      {DateTime? startTimestamp}) async {
    if (_enableAutoTransactions == false) {
      return null;
    }

    if (routeName == null) {
      return null;
    }

    if (routeName == '/') {
      routeName = 'root ("/")';
    }

    final transactionContext = SentryTransactionContext(
      routeName,
      SentrySpanOperations.uiLoad,
      transactionNameSource: SentryTransactionNameSource.component,
      // ignore: invalid_use_of_internal_member
      origin: SentryTraceOrigins.autoNavigationRouteObserver,
    );

    final transaction = _hub?.startTransactionWithContext(
      transactionContext,
      waitForChildren: true,
      autoFinishAfter: _autoFinishAfter,
      trimEnd: true,
      startTimestamp: startTimestamp,
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

    // if _enableAutoTransactions is enabled but there's no traces sample rate
    if (transaction is NoOpSentrySpan) {
      return null;
    }

    if (arguments != null) {
      transaction?.setData('route_settings_arguments', arguments);
    }

    _hub?.configureScope((scope) {
      scope.span ??= transaction;
    });

    await _native?.beginNativeFramesCollection();

    return transaction;
  }
}
