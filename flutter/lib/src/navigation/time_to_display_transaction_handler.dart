import 'package:meta/meta.dart';
import '../../sentry_flutter.dart';
import '../native/sentry_native.dart';

enum TimeToDisplayType { timeToInitialDisplay, timeToFullDisplay }

@internal
abstract class ITimeToDisplayTransactionHandler {
  Future<ISentrySpan?> startTransaction(String? routeName, Object? arguments,
      {DateTime? startTimestamp});

  ISentrySpan createSpan(ISentrySpan transaction, TimeToDisplayType type,
      String routeName, DateTime startTimestamp);
}

@internal
class TimeToDisplayTransactionHandler extends ITimeToDisplayTransactionHandler {
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
      'ui.load',
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

  @override
  ISentrySpan createSpan(ISentrySpan transaction, TimeToDisplayType type,
      String routeName, DateTime startTimestamp) {
    String operation;
    String description;
    switch (type) {
      case TimeToDisplayType.timeToInitialDisplay:
        operation = SentryTraceOrigins.uiTimeToInitialDisplay;
        description = '$routeName initial display';
        break;
      case TimeToDisplayType.timeToFullDisplay:
        operation = SentryTraceOrigins.uiTimeToFullDisplay;
        description = '$routeName full display';
        break;
    }
    return transaction.startChild(operation,
        description: description, startTimestamp: startTimestamp);
  }

  static void finishSpan(
      {required ISentrySpan span,
      required ISentrySpan transaction,
      DateTime? endTimestamp,
      SentryMeasurement? measurement,
      SpanStatus? status}) {
    if (measurement != null) {
      transaction.setMeasurement(measurement.name, measurement.value,
          unit: measurement.unit);
    }
    span.finish(status: status, endTimestamp: endTimestamp);
  }
}
