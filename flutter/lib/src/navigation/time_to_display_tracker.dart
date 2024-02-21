import 'dart:async';

import 'package:meta/meta.dart';
import 'package:sentry_flutter/src/navigation/time_to_full_display_tracker.dart';

import '../../sentry_flutter.dart';
import '../frame_callback_handler.dart';
import '../integrations/app_start/app_start_tracker.dart';
import '../integrations/integrations.dart';
import '../native/sentry_native.dart';
import '../sentry_flutter_measurement.dart';
import 'time_to_display_transaction_handler.dart';
import 'time_to_initial_display_tracker.dart';

@internal
class TimeToDisplayTracker {
  final SentryNative? _native;
  final AppStartTracker _appStartTracker;
  final TimeToDisplayTransactionHandler _ttdTransactionHandler;
  final TimeToInitialDisplayTracker _ttidTracker;
  final bool _enableTimeToFullDisplayTracing;
  final TimeToFullDisplayTracker _ttfdTracker;

  TimeToDisplayTracker({
    required bool enableTimeToFullDisplayTracing,
    required TimeToDisplayTransactionHandler ttdTransactionHandler,
    AppStartTracker? appStartTracker,
    TimeToInitialDisplayTracker? ttidTracker,
    TimeToFullDisplayTracker? ttfdTracker,
  })  : _native = SentryFlutter.native,
        _enableTimeToFullDisplayTracing = enableTimeToFullDisplayTracing,
        _ttdTransactionHandler = ttdTransactionHandler,
        _appStartTracker = appStartTracker ?? AppStartTracker(),
        _ttfdTracker = ttfdTracker ?? TimeToFullDisplayTracker(),
        _ttidTracker = ttidTracker ?? TimeToInitialDisplayTracker();

  Future<void> startTracking(String? routeName, Object? arguments) async {
    final startTimestamp = DateTime.now();
    final isRootScreen = routeName == '/';
    final didFetchAppStart = _native?.didFetchAppStart;
    if (isRootScreen && didFetchAppStart == false) {
      return _trackAppStartTTD(routeName, arguments);
    } else {
      return _trackRegularRouteTTD(routeName, arguments, startTimestamp);
    }
  }

  /// This method listens for the completion of the app's start process via
  /// [AppStartTracker], then:
  /// - Starts a transaction with the app start start timestamp
  /// - Starts TTID and optionally TTFD spans based on the app start start timestamp
  /// - Finishes the TTID span immediately with the app start end timestamp
  ///
  /// We start and immediately finish the TTID span since we cannot mutate the history of spans.
  Future<void> _trackAppStartTTD(String? routeName, Object? arguments) async {
    final appStartInfo = await _appStartTracker.getAppStartInfo();
    final name = routeName ?? SentryNavigatorObserver.currentRouteName;

    if (appStartInfo == null || name == null) return;

    final transaction = await _ttdTransactionHandler.startTransaction(
        name, arguments,
        startTimestamp: appStartInfo.start);
    if (transaction == null) return;

    await _ttidTracker.trackAppStart(transaction, appStartInfo, name);

    if (_enableTimeToFullDisplayTracing) {
      _ttfdTracker.startTracking(transaction, appStartInfo.start, name);
    }
  }

  // Handles measuring navigation for regular routes
  Future<void> _trackRegularRouteTTD(
      String? routeName, Object? arguments, DateTime startTimestamp) async {
    final transaction = await _ttdTransactionHandler
        .startTransaction(routeName, arguments, startTimestamp: startTimestamp);

    if (transaction == null || routeName == null) return;


    await _ttidTracker.trackRegularRoute(transaction, startTimestamp, routeName);

    if (_enableTimeToFullDisplayTracing) {
      _ttfdTracker.startTracking(transaction, startTimestamp, routeName);
    }
  }

  @internal
  Future<void> reportFullyDisplayed() async {
    return _ttfdTracker.reportFullyDisplayed();
  }
}
