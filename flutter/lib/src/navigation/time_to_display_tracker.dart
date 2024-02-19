import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../integrations/integrations.dart';
import '../native/sentry_native.dart';
import 'display_strategy_evaluator.dart';
import 'time_to_display_transaction_handler.dart';

@internal
class TimeToDisplayTracker {
  final Hub _hub;
  final SentryNative? _native;
  final TimeToDisplayTransactionHandler _transactionHandler;
  final IFrameCallbackHandler _frameCallbackHandler;

  static DateTime? _startTimestamp;
  static DateTime? _ttidEndTimestamp;
  static ISentrySpan? _ttidSpan;
  static ISentrySpan? _ttfdSpan;
  static Timer? _ttfdTimer;
  static ISentrySpan? _transaction;

  @visibleForTesting
  Duration ttfdAutoFinishAfter = Duration(seconds: 30);

  SentryFlutterOptions? get _options => _hub.options is SentryFlutterOptions
      // ignore: invalid_use_of_internal_member
      ? _hub.options as SentryFlutterOptions
      : null;

  TimeToDisplayTracker({
    required Hub? hub,
    required bool enableAutoTransactions,
    required Duration autoFinishAfter,
    IFrameCallbackHandler? frameCallbackHandler,
    TimeToDisplayTransactionHandler? transactionHandler,
  })  : _hub = hub ?? HubAdapter(),
        _native = SentryFlutter.native,
        _frameCallbackHandler = frameCallbackHandler ?? FrameCallbackHandler(),
        _transactionHandler = transactionHandler ??
            TimeToDisplayTransactionHandler(
              hub: hub,
              enableAutoTransactions: enableAutoTransactions,
              autoFinishAfter: autoFinishAfter,
            );

  void startMeasurement(String? routeName, Object? arguments) async {
    final startTimestamp = DateTime.now();
    _startTimestamp = startTimestamp;

    final isRootScreen = routeName == '/';
    final didFetchAppStart = _native?.didFetchAppStart;
    if (isRootScreen && didFetchAppStart == false) {
      _handleAppStartMeasurement(routeName, arguments);
    } else {
      _handleRegularRouteMeasurement(routeName, arguments, startTimestamp);
    }
  }

  /// This method listens for the completion of the app's start process via
  /// [AppStartTracker], then:
  /// - Starts a transaction with the app start start timestamp
  /// - Starts TTID and optionally TTFD spans based on the app start start timestamp
  /// - Finishes the TTID span immediately with the app start end timestamp
  ///
  /// We start and immediately finish the TTID span since we cannot mutate the history of spans.
  void _handleAppStartMeasurement(String? routeName, Object? arguments) {
    AppStartTracker().onAppStartComplete((appStartInfo) async {
      final name = routeName ?? SentryNavigatorObserver.currentRouteName;
      if (appStartInfo == null || name == null) return;

      final transaction = await _transactionHandler.startTransaction(
          name, arguments,
          startTimestamp: appStartInfo.start);
      if (transaction == null) return;
      _transaction = transaction;

      final ttidSpan = _transactionHandler.createSpan(
          transaction,
          TimeToDisplayType.timeToInitialDisplay,
          name,
          appStartInfo.start);

      if (_options?.enableTimeToFullDisplayTracing == true) {
        _ttfdSpan = _transactionHandler.createSpan(transaction,
            TimeToDisplayType.timeToFullDisplay, name, appStartInfo.start);
      }

      TimeToDisplayTransactionHandler.finishSpan(
          transaction: transaction,
          span: ttidSpan,
          endTimestamp: appStartInfo.end,
          measurement: appStartInfo.measurement);
    });
  }

  // Handles measuring navigation for regular routes
  void _handleRegularRouteMeasurement(
      String? routeName, Object? arguments, DateTime startTimestamp) async {
    final transaction = await _transactionHandler
        .startTransaction(routeName, arguments, startTimestamp: startTimestamp);

    if (transaction == null || routeName == null) return;
    _transaction = transaction;

    _initializeTimeToDisplaySpans(transaction, routeName, startTimestamp);

    final ttidSpan = _ttidSpan;
    if (ttidSpan == null) return;

    _finishInitialDisplay(ttidSpan, transaction, routeName, startTimestamp);
  }

  void _initializeTimeToDisplaySpans(
      ISentrySpan transaction, String routeName, DateTime startTimestamp) {
    _ttidSpan = _transactionHandler.createSpan(transaction,
        TimeToDisplayType.timeToInitialDisplay, routeName, startTimestamp);
    if (_options?.enableTimeToFullDisplayTracing == true) {
      _ttfdSpan = _transactionHandler.createSpan(transaction,
          TimeToDisplayType.timeToFullDisplay, routeName, startTimestamp);
      _ttfdTimer = Timer(ttfdAutoFinishAfter, () async {
        final ttfdSpan = _ttfdSpan;
        final ttfdEndTimestamp = _ttidEndTimestamp;
        if (ttfdSpan == null ||
            ttfdSpan.finished == true ||
            ttfdEndTimestamp == null) {
          return;
        }
        TimeToDisplayTransactionHandler.finishSpan(
            transaction: transaction,
            span: ttfdSpan,
            endTimestamp: ttfdEndTimestamp,
            status: SpanStatus.deadlineExceeded());
      });
    }
  }

  void _finishInitialDisplay(ISentrySpan ttidSpan, ISentrySpan transaction,
      String routeName, DateTime startTimestamp) async {
    final endTimestamp = await _determineEndTimeOfTTID(routeName);
    if (endTimestamp == null) return;
    _ttidEndTimestamp = endTimestamp;

    final duration = endTimestamp.difference(startTimestamp).inMilliseconds;
    final measurement = SentryMeasurement('time_to_initial_display', duration,
        unit: DurationSentryMeasurementUnit.milliSecond);

    TimeToDisplayTransactionHandler.finishSpan(
        transaction: transaction,
        span: ttidSpan,
        endTimestamp: endTimestamp,
        measurement: measurement);
  }

  Future<DateTime?> _determineEndTimeOfTTID(String routeName) async {
    DateTime? endTimestamp;
    final endTimeCompleter = Completer<DateTime>();

    _frameCallbackHandler.addPostFrameCallback((_) {
      endTimestamp = DateTime.now();
      endTimeCompleter.complete(endTimestamp);
    });

    final strategyDecision =
        await DisplayStrategyEvaluator().decideStrategy(routeName);

    if (strategyDecision == TimeToDisplayStrategy.manual) {
      endTimestamp = DateTime.now();
    } else if (!endTimeCompleter.isCompleted) {
      // In approximation we want to wait until addPostFrameCallback has triggered
      await endTimeCompleter.future;
    }

    return endTimestamp;
  }

  @internal
  static void reportInitiallyDisplayed({String? routeName}) {
    routeName = routeName ?? SentryNavigatorObserver.currentRouteName;

    if (routeName == null) return;
    DisplayStrategyEvaluator().reportManual(routeName);
  }

  @internal
  static void reportFullyDisplayed() {
    _ttfdTimer?.cancel();
    final endTimestamp = DateTime.now();
    final startTimestamp = _startTimestamp;
    final transaction = _transaction;
    final ttfdSpan = _ttfdSpan;
    if (startTimestamp == null || transaction == null || ttfdSpan == null) {
      return;
    }
    final duration = endTimestamp.difference(startTimestamp).inMilliseconds;
    final measurement = SentryMeasurement('time_to_full_display', duration,
        unit: DurationSentryMeasurementUnit.milliSecond);
    TimeToDisplayTransactionHandler.finishSpan(
        transaction: transaction,
        span: ttfdSpan,
        endTimestamp: endTimestamp,
        measurement: measurement);
  }
}

abstract class IFrameCallbackHandler {
  void addPostFrameCallback(FrameCallback callback, {String debugLabel});
}

class FrameCallbackHandler implements IFrameCallbackHandler {
  @override
  void addPostFrameCallback(FrameCallback callback,
      {String debugLabel = 'callback'}) {
    SchedulerBinding.instance.addPostFrameCallback(callback);
  }
}

class MockFrameCallbackHandler implements IFrameCallbackHandler {
  FrameCallback? storedCallback;

  @override
  void addPostFrameCallback(FrameCallback callback,
      {String debugLabel = 'callback'}) {
    Future.delayed(Duration(milliseconds: 500), () {
      callback(Duration.zero);
    });
  }
}
