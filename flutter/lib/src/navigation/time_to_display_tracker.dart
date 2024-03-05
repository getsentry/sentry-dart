// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:meta/meta.dart';
import '../integrations/integrations.dart';

import '../../sentry_flutter.dart';
import '../native/sentry_native.dart';
import 'time_to_initial_display_tracker.dart';

@internal
class TimeToDisplayTracker {
  final Hub? _hub;
  final bool? _enableAutoTransactions;
  final Duration? _autoFinishAfter;
  final SentryNative? _native;
  final TimeToInitialDisplayTracker _ttidTracker;

  // TODO We can use _hub.options to fetch the ttfd flag
  bool get _enableTimeToFullDisplayTracing => false;

  TimeToDisplayTracker({
    required Hub? hub,
    required bool? enableAutoTransactions,
    required Duration? autoFinishAfter,
    TimeToInitialDisplayTracker? ttidTracker,
  })  : _native = SentryFlutter.native,
        _hub = hub ?? HubAdapter(),
        _enableAutoTransactions = enableAutoTransactions,
        _autoFinishAfter = autoFinishAfter,
        _ttidTracker = ttidTracker ?? TimeToInitialDisplayTracker();

  Future<ISentrySpan?> _startTransaction(String? routeName, Object? arguments,
      {DateTime? startTimestamp}) async {
    if (_enableAutoTransactions == false) {
      return null;
    }

    if (routeName == null) {
      return null;
    }

    final transactionContext = SentryTransactionContext(
      routeName,
      SentrySpanOperations.uiLoad,
      transactionNameSource: SentryTransactionNameSource.component,
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

  Future<void> startTracking(String? routeName, Object? arguments) async {
    final startTimestamp = DateTime.now();
    if (routeName == '/') {
      routeName = 'root ("/")';
    }
    final isRootScreen = routeName == 'root ("/")';
    final didFetchAppStart = _native?.didFetchAppStart;

    if (routeName == null) return;

    if (isRootScreen && didFetchAppStart == false) {
      // Dart cannot infer here that routeName is not nullable
      await _trackAppStartTTD(routeName, arguments);
    } else {
      await _trackRegularRouteTTD(routeName, arguments, startTimestamp);
    }
    _ttidTracker.clear();
  }

  /// This method listens for the completion of the app's start process via
  /// [AppStartTracker], then:
  /// - Starts a transaction with the app start start timestamp
  /// - Starts TTID and optionally TTFD spans based on the app start start timestamp
  /// - Finishes the TTID span immediately with the app start end timestamp
  ///
  /// We start and immediately finish the TTID span since we cannot mutate the history of spans.
  Future<void> _trackAppStartTTD(String routeName, Object? arguments) async {
    final appStartInfo = await NativeAppStartIntegration.getAppStartInfo();
    if (appStartInfo == null) return;

    final transaction = await _startTransaction(routeName, arguments, startTimestamp: appStartInfo.start);
    if (transaction == null) return;

    if (_enableTimeToFullDisplayTracing) {
      // TODO: implement TTFD
    }

    await _ttidTracker.trackAppStart(transaction, appStartInfo, routeName);
  }

  /// Starts and finishes Time To Display spans for regular routes meaning routes that are not root.
  Future<void> _trackRegularRouteTTD(
      String routeName, Object? arguments, DateTime startTimestamp) async {
    final transaction = await _startTransaction(routeName, arguments, startTimestamp: startTimestamp);
    if (transaction == null) return;

    if (_enableTimeToFullDisplayTracing) {
      // TODO: implement TTFD
    }

    await _ttidTracker.trackRegularRoute(
        transaction, startTimestamp, routeName);
  }

  @internal
  Future<void> reportFullyDisplayed() async {
    // TODO: implement TTFD
  }

  void clear() {
    _ttidTracker.clear();
  }
}
