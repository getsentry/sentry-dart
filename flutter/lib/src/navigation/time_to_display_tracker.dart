import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../frame_callback_handler.dart';
import '../integrations/integrations.dart';
import '../native/sentry_native.dart';
import '../sentry_flutter_measurement.dart';
import 'time_to_display_transaction_handler.dart';
import 'time_to_initial_display_tracker.dart';

@internal
class TimeToDisplayTracker {
  final Hub _hub;
  final SentryNative? _native;
  final TimeToDisplayTransactionHandler _transactionHandler;
  final TTIDEndTimeTracker _timeToInitialDisplayTracker;

  // We need to keep these static to be able to access them from reportFullyDisplayed
  static DateTime? _startTimestamp;
  static DateTime? _ttidEndTimestamp;
  static ISentrySpan? _ttfdSpan;
  static Timer? _ttfdTimer;
  static ISentrySpan? _transaction;

  static ISentrySpan? get transaction => _transaction;

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
        _transactionHandler = transactionHandler ??
            TimeToDisplayTransactionHandler(
              hub: hub,
              enableAutoTransactions: enableAutoTransactions,
              autoFinishAfter: autoFinishAfter,
            ),
        _timeToInitialDisplayTracker = TTIDEndTimeTracker();

  Future<void> startMeasurement(String? routeName, Object? arguments) async {
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

      final ttidSpan = _transactionHandler.createSpan(transaction,
          TimeToDisplayType.timeToInitialDisplay, name, appStartInfo.start);

      if (_options?.enableTimeToFullDisplayTracing == true) {
        _initializeTTFD(transaction, appStartInfo.start, name);
      }

      _setAppStartMeasurement(ttidSpan, appStartInfo);

      await ttidSpan.finish(endTimestamp: appStartInfo.end);
    });
  }

  void _setAppStartMeasurement(ISentrySpan transaction, AppStartInfo appStartInfo) {
    transaction.setMeasurement(appStartInfo.measurement.name, appStartInfo.measurement.value, unit: appStartInfo.measurement.unit);

    final ttidMeasurement = SentryFlutterMeasurement.timeToInitialDisplay(Duration(milliseconds: appStartInfo.measurement.value.toInt()));
    transaction.setMeasurement(ttidMeasurement.name, ttidMeasurement.value, unit: ttidMeasurement.unit);
  }

  // Handles measuring navigation for regular routes
  void _handleRegularRouteMeasurement(
      String? routeName, Object? arguments, DateTime startTimestamp) async {
    final transaction = await _transactionHandler
        .startTransaction(routeName, arguments, startTimestamp: startTimestamp);

    if (transaction == null || routeName == null) return;
    _transaction = transaction;

    await _trackTTID(transaction, startTimestamp, routeName);

    if (_options?.enableTimeToFullDisplayTracing == true) {
      _initializeTTFD(transaction, startTimestamp, routeName);
    }
  }

  Future<void> _trackTTID(ISentrySpan transaction,
      DateTime startTimestamp, String routeName) async {
    final endTimestamp = await _timeToInitialDisplayTracker.determineEndTime();
    _ttidEndTimestamp = endTimestamp;
    final ttidSpan = _transactionHandler.createSpan(transaction,
        TimeToDisplayType.timeToInitialDisplay, routeName, startTimestamp);
    return ttidSpan.finish(endTimestamp: endTimestamp);
  }

  void _initializeTTFD(
      ISentrySpan transaction, DateTime startTimestamp, String routeName) {
    _ttfdSpan = _transactionHandler.createSpan(transaction,
        TimeToDisplayType.timeToFullDisplay, routeName, startTimestamp);
    _ttfdTimer = Timer(ttfdAutoFinishAfter, handleTimeToFullDisplayTimeout);
  }

  void handleTimeToFullDisplayTimeout() {
    final ttfdSpan = _ttfdSpan;
    final endTimestamp = _ttidEndTimestamp ?? DateTime.now();
    final startTimestamp = _startTimestamp;
    if (ttfdSpan == null || ttfdSpan.finished == true || startTimestamp == null) return;

    _setTTFDMeasurement(startTimestamp, endTimestamp);
    ttfdSpan.finish(status: SpanStatus.deadlineExceeded(), endTimestamp: endTimestamp);
  }

  @internal
  static void reportFullyDisplayed() {
    _ttfdTimer?.cancel();
    final endTimestamp = DateTime.now();
    final startTimestamp = _startTimestamp;
    final ttfdSpan = _ttfdSpan;
    if (ttfdSpan == null || ttfdSpan.finished == true || startTimestamp == null) return;

    _setTTFDMeasurement(startTimestamp, endTimestamp);
    ttfdSpan.finish(endTimestamp: endTimestamp);
  }

  static void _setTTFDMeasurement(DateTime startTimestamp, DateTime endTimestamp) {
    final duration = endTimestamp.difference(startTimestamp);
    final measurement = SentryFlutterMeasurement.timeToFullDisplay(duration);
    _transaction?.setMeasurement(measurement.name, measurement.value, unit: measurement.unit);
  }
}
