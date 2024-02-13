import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../integrations/integrations.dart';
import '../native/sentry_native.dart';
import 'navigation_transaction_manager.dart';

@internal
class NavigationTimingManager {
  static NavigationTimingManager? _instance;
  final Hub _hub;
  final Duration _autoFinishAfter;
  final SentryNative? _native;
  late final NavigationTransactionManager? _transactionManager;

  static ISentrySpan? _ttidSpan;
  static ISentrySpan? _ttfdSpan;
  static DateTime? _startTimestamp;

  NavigationTimingManager._({
    Hub? hub,
    Duration autoFinishAfter = const Duration(seconds: 3),
    SentryNative? native,
  })  : _hub = hub ?? HubAdapter(),
        _autoFinishAfter = autoFinishAfter,
        _native = native {
    _transactionManager =
        NavigationTransactionManager(_hub, _native, _autoFinishAfter);
  }

  factory NavigationTimingManager({
    Hub? hub,
    Duration autoFinishAfter = const Duration(seconds: 3),
  }) {
    _instance ??= NavigationTimingManager._(
      hub: hub ?? HubAdapter(),
      autoFinishAfter: autoFinishAfter,
      native: SentryFlutter.native,
    );

    return _instance!;
  }

  void startMeasurement(String routeName) async {
    _startTimestamp = DateTime.now();

    // This has multiple branches
    // - normal screen navigation -> affects all screens
    // - app start navigation -> only affects root screen
    final isRootScreen = routeName == '/' || routeName == 'root ("/")';
    final didFetchAppStart = _native?.didFetchAppStart;
    if (isRootScreen && didFetchAppStart == false) {
      // App start - this is a special edge case that only happens once
      AppStartTracker().onAppStartComplete((appStartInfo) {
        // Create a transaction based on app start start time
        // Then create ttidSpan and finish immediately with the app start start & end time
        // This is a small workaround to pass the correct time stamps since we cannot mutate
        // timestamps of transactions or spans in history
        if (appStartInfo != null) {
          final transaction = _transactionManager?.startTransaction(
              routeName, appStartInfo.start);
          if (transaction != null) {
            final ttidSpan = _createTTIDSpan(transaction, routeName, appStartInfo.start);
            ttidSpan.finish(endTimestamp: appStartInfo.end);
          }
        }
      });
    } else {
      final transaction =
          _transactionManager?.startTransaction(routeName, _startTimestamp!);

      if (transaction == null) {
        return;
      }

      _initializeSpans(transaction, routeName, _startTimestamp!);

      final endTimestamp = await _determineEndTime(routeName);

      final duration = endTimestamp.difference(_startTimestamp!).inMilliseconds;
      _finishSpan(_ttidSpan!, transaction, 'time_to_initial_display', duration,
          endTimestamp);
    }
  }

  Future<DateTime> _determineEndTime(String routeName) async {
    DateTime? approximationEndTime;
    final endTimeCompleter = Completer<DateTime>();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      approximationEndTime = DateTime.now();
      endTimeCompleter.complete(approximationEndTime!);
    });

    final strategyDecision =
        await SentryDisplayTracker().decideStrategyWithTimeout2(routeName);

    if (strategyDecision == StrategyDecision.manual &&
        !endTimeCompleter.isCompleted) {
      approximationEndTime = DateTime.now();
      endTimeCompleter.complete(approximationEndTime);
    } else if (!endTimeCompleter.isCompleted) {
      // If the decision is not manual and the completer hasn't been completed, await it.
      await endTimeCompleter.future;
    }

    return approximationEndTime!;
  }

  void reportInitiallyDisplayed(String routeName) {
    SentryDisplayTracker().reportManual2(routeName);
  }

  void reportFullyDisplayed() {
    final endTimestamp = DateTime.now();
    final transaction = Sentry.getSpan();
    final duration = endTimestamp.difference(_startTimestamp!).inMilliseconds;
    if (_ttidSpan == null || transaction == null) {
      return;
    }
    _finishSpan(_ttfdSpan!, transaction, 'time_to_full_display', duration, endTimestamp);
  }

  void _initializeSpans(ISentrySpan? transaction, String routeName, DateTime startTimestamp) {
    final options = _hub.options is SentryFlutterOptions
        // ignore: invalid_use_of_internal_member
        ? _hub.options as SentryFlutterOptions
        : null;
    if (transaction == null) return;
    _ttidSpan = _createTTIDSpan(transaction, routeName, startTimestamp);
    if (options?.enableTimeToFullDisplayTracing == true) {
      _ttfdSpan = _createTTFDSpan(transaction, routeName, startTimestamp);
    }
  }

  ISentrySpan _createTTIDSpan(ISentrySpan transaction, String routeName, DateTime startTimestamp) {
    return transaction.startChild(
      SentryTraceOrigins.uiTimeToInitialDisplay,
      description: '$routeName initial display',
      startTimestamp: startTimestamp,
    );
  }

  ISentrySpan _createTTFDSpan(ISentrySpan transaction, String routeName, DateTime startTimestamp) {
    return transaction.startChild(
      SentryTraceOrigins.uiTimeToFullDisplay,
      description: '$routeName full display',
      startTimestamp: startTimestamp,
    );
  }

  void _finishSpan(ISentrySpan span, ISentrySpan transaction,
      String measurementName, int duration, DateTime endTimestamp) {
    transaction.setMeasurement(measurementName, duration,
        unit: DurationSentryMeasurementUnit.milliSecond);
    span.finish(endTimestamp: endTimestamp);
  }
}
