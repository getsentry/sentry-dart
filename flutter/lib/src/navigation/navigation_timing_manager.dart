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
    final options = _hub.options is SentryFlutterOptions
        // ignore: invalid_use_of_internal_member
        ? _hub.options as SentryFlutterOptions
        : null;

    // This marks the start timestamp of both TTID and TTFD spans
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
        // Create ttidSpan and finish immediately with the app start start & end time
        // This is a small workaround to pass the correct time stamps since we mutate
        // timestamps of transactions or spans in history
        if (appStartInfo != null) {
          final transaction = _transactionManager?.startTransaction(
              routeName, appStartInfo.start);
          if (transaction != null) {
            final ttidSpan = _startTimeToInitialDisplaySpan(
                routeName, transaction, appStartInfo.start);
            ttidSpan.finish(endTimestamp: appStartInfo.end);
          }
        }
      });
    } else {
      DateTime? approximationEndTime;
      final endTimeCompleter = Completer<DateTime>();
      final transaction =
          _transactionManager?.startTransaction(routeName, _startTimestamp!);

      if (transaction != null) {
        if (options?.enableTimeToFullDisplayTracing == true) {
          _ttfdSpan = transaction.startChild('ui.load.full_display',
              description: '$routeName full display',
              startTimestamp: _startTimestamp!);

          _ttfdSpan = _startTimeToFullDisplaySpan(
              routeName, transaction, _startTimestamp!);
        }
        _ttidSpan = _startTimeToInitialDisplaySpan(
            routeName, transaction, _startTimestamp!);
      }

      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        approximationEndTime = DateTime.now();
        endTimeCompleter.complete(approximationEndTime);
      });

      final strategyDecision =
          await SentryDisplayTracker().decideStrategyWithTimeout2(routeName);

      switch (strategyDecision) {
        case StrategyDecision.manual:
          final endTimestamp = DateTime.now();
          final duration = endTimestamp.millisecondsSinceEpoch -
              _startTimestamp!.millisecondsSinceEpoch;
          _endTimeToInitialDisplaySpan(_ttidSpan!, transaction!, endTimestamp, duration);
          break;
        case StrategyDecision.approximation:
          if (approximationEndTime == null) {
            await endTimeCompleter.future;
          }
          final duration = approximationEndTime!.millisecondsSinceEpoch -
              _startTimestamp!.millisecondsSinceEpoch;
          _endTimeToInitialDisplaySpan(
              _ttidSpan!, transaction!, approximationEndTime!, duration);
          await _ttidSpan?.finish(endTimestamp: approximationEndTime);
          break;
        default:
          print('Unknown strategy decision: $strategyDecision');
      }
    }
  }

  void reportInitiallyDisplayed(String routeName) {
    SentryDisplayTracker().reportManual2(routeName);
  }

  void reportFullyDisplayed() {
    final endTime = DateTime.now();
    final transaction = Sentry.getSpan();
    final duration = endTime.millisecondsSinceEpoch -
        _startTimestamp!.millisecondsSinceEpoch;
    if (_ttfdSpan != null && transaction != null) {
      _endTimeToFullDisplaySpan(_ttfdSpan!, transaction, endTime, duration);
    }
  }

  static ISentrySpan _startTimeToInitialDisplaySpan(
      String routeName, ISentrySpan transaction, DateTime startTimestamp) {
    return transaction.startChild(SentryTraceOrigins.uiTimeToInitialDisplay,
        description: '$routeName initial display',
        startTimestamp: startTimestamp);
  }

  static ISentrySpan _startTimeToFullDisplaySpan(
      String routeName, ISentrySpan transaction, DateTime startTimestamp) {
    return transaction.startChild(SentryTraceOrigins.uiTimeToFullDisplay,
        description: '$routeName full display', startTimestamp: startTimestamp);
  }

  static void _endTimeToInitialDisplaySpan(ISentrySpan ttidSpan,
      ISentrySpan transaction, DateTime endTimestamp, int duration) async {
    transaction.setMeasurement('time_to_initial_display', duration,
        unit: DurationSentryMeasurementUnit.milliSecond);
    await ttidSpan.finish(endTimestamp: endTimestamp);
  }

  static void _endTimeToFullDisplaySpan(ISentrySpan ttfdSpan,
      ISentrySpan transaction, DateTime endTimestamp, int duration) async {
    transaction.setMeasurement('time_to_full_display', duration,
        unit: DurationSentryMeasurementUnit.milliSecond);
    await ttfdSpan.finish(endTimestamp: endTimestamp);
  }
}
