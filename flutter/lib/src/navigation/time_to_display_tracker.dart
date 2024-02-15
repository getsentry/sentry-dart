import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../integrations/integrations.dart';
import '../native/sentry_native.dart';
import 'display_strategy_evaluator.dart';

@internal
class TimeToDisplayTracker {
  final Hub _hub;
  final bool _enableAutoTransactions;
  final Duration _autoFinishAfter;
  final SentryNative? _native;

  static DateTime? _startTimestamp;
  static DateTime? _ttidEndTimestamp;
  static ISentrySpan? _ttidSpan;
  static ISentrySpan? _ttfdSpan;
  static Timer? _ttfdTimer;

  SentryFlutterOptions? get _options => _hub.options is SentryFlutterOptions
      // ignore: invalid_use_of_internal_member
      ? _hub.options as SentryFlutterOptions
      : null;

  TimeToDisplayTracker({
    required Hub? hub,
    required bool enableAutoTransactions,
    required Duration autoFinishAfter,
  })  : _hub = hub ?? HubAdapter(),
        _enableAutoTransactions = enableAutoTransactions,
        _autoFinishAfter = autoFinishAfter,
        _native = SentryFlutter.native;

  Future<ISentrySpan?> _startTransaction(String? routeName, Object? arguments,
      {DateTime? startTimestamp}) async {
    if (!_enableAutoTransactions) {
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

    final transaction = _hub.startTransactionWithContext(
      transactionContext,
      waitForChildren: true,
      autoFinishAfter: _autoFinishAfter,
      trimEnd: true,
      bindToScope: true,
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
      transaction.setData('route_settings_arguments', arguments);
    }

    await _native?.beginNativeFramesCollection();

    return transaction;
  }

  void startMeasurement(String? routeName, Object? arguments) async {
    _ttidSpan = null;
    _ttfdSpan = null;

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
      final routeName = SentryNavigatorObserver.currentRouteName;
      if (appStartInfo == null || routeName == null) return;

      final transaction = await _startTransaction(routeName, arguments,
          startTimestamp: appStartInfo.start);
      if (transaction == null) return;

      final ttidSpan =
          _createTTIDSpan(transaction, routeName, appStartInfo.start);
      if (_options?.enableTimeToFullDisplayTracing == true) {
        _ttfdSpan = _createTTFDSpan(transaction, routeName, appStartInfo.start);
      }
      _finishSpan(ttidSpan, transaction, appStartInfo.end,
          measurement: appStartInfo.measurement);
    });
  }

  // Handles measuring navigation for regular routes
  void _handleRegularRouteMeasurement(
      String? routeName, Object? arguments, DateTime startTimestamp) async {
    final transaction = await _startTransaction(routeName, arguments,
        startTimestamp: startTimestamp);

    if (transaction == null || routeName == null) return;

    _initializeTimeToDisplaySpans(transaction, routeName, startTimestamp);

    final ttidSpan = _ttidSpan;
    if (ttidSpan == null) return;

    _finishInitialDisplay(ttidSpan, transaction, routeName, startTimestamp);
  }

  void _initializeTimeToDisplaySpans(
      ISentrySpan transaction, String routeName, DateTime startTimestamp) {
    _ttidSpan = _createTTIDSpan(transaction, routeName, startTimestamp);
    if (_options?.enableTimeToFullDisplayTracing == true) {
      _ttfdSpan = _createTTFDSpan(transaction, routeName, startTimestamp);
      final ttfdAutoFinishAfter = Duration(seconds: 30);
      _ttfdTimer = Timer(ttfdAutoFinishAfter, () {
        if (_ttfdSpan?.finished == true) {
          return;
        }
        _finishSpan(_ttfdSpan!, transaction, _ttidEndTimestamp!,
            status: SpanStatus.deadlineExceeded());
      });
    }
  }

  ISentrySpan _createTTIDSpan(
      ISentrySpan transaction, String routeName, DateTime startTimestamp) {
    return transaction.startChild(
      SentryTraceOrigins.uiTimeToInitialDisplay,
      description: '$routeName initial display',
      startTimestamp: startTimestamp,
    );
  }

  ISentrySpan _createTTFDSpan(
      ISentrySpan transaction, String routeName, DateTime startTimestamp) {
    return transaction.startChild(
      SentryTraceOrigins.uiTimeToFullDisplay,
      description: '$routeName full display',
      startTimestamp: startTimestamp,
    );
  }

  Future<DateTime?> _determineEndTimeOfTTID(String routeName) async {
    DateTime? endTimestamp;
    final endTimeCompleter = Completer<DateTime>();

    SchedulerBinding.instance.addPostFrameCallback((_) {
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
  static void reportInitiallyDisplayed(String routeName) {
    DisplayStrategyEvaluator().reportManual(routeName);
  }

  @internal
  static void reportFullyDisplayed() {
    _finishFullDisplay();
  }

  static void _finishFullDisplay() {
    _ttfdTimer?.cancel();
    final endTimestamp = DateTime.now();
    final startTimestamp = _startTimestamp;
    final transaction = Sentry.getSpan();
    final ttfdSpan = _ttfdSpan;
    if (startTimestamp == null || transaction == null || ttfdSpan == null) {
      return;
    }
    final duration = endTimestamp.difference(startTimestamp).inMilliseconds;
    final measurement = SentryMeasurement('time_to_full_display', duration,
        unit: DurationSentryMeasurementUnit.milliSecond);
    _finishSpan(ttfdSpan, transaction, endTimestamp, measurement: measurement);
  }

  void _finishInitialDisplay(ISentrySpan ttidSpan, ISentrySpan transaction,
      String routeName, DateTime startTimestamp) async {
    final endTimestamp = await _determineEndTimeOfTTID(routeName);
    if (endTimestamp == null) return;
    _ttidEndTimestamp = endTimestamp;

    final duration = endTimestamp.difference(startTimestamp).inMilliseconds;
    final measurement = SentryMeasurement('time_to_initial_display', duration,
        unit: DurationSentryMeasurementUnit.milliSecond);
    _finishSpan(ttidSpan, transaction, endTimestamp, measurement: measurement);
  }

  static void _finishSpan(
      ISentrySpan span, ISentrySpan transaction, DateTime endTimestamp,
      {SentryMeasurement? measurement, SpanStatus? status}) {
    if (measurement != null) {
      transaction.setMeasurement(measurement.name, measurement.value,
          unit: measurement.unit);
    }
    span.finish(status: status, endTimestamp: endTimestamp);
  }
}
