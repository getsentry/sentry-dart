import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';

/// Represents the current route and allows to report the time to full display.
///
/// Make sure to get this before you do long running operations after which
/// you want to report the time to full display in your widget.
///
/// ```dart
/// final display = SentryFlutter.currentDisplay();
///
/// // Do long running operations...
///
/// await display.reportFullyDisplayed();
/// ```
class SentryDisplay {
  final Hub _hub;
  final SpanId spanId;

  SentryDisplay(this.spanId, {Hub? hub}) : _hub = hub ?? HubAdapter();

  Future<void> reportFullyDisplayed() async {
    // ignore: invalid_use_of_internal_member
    final options = _hub.options;
    if (options is! SentryFlutterOptions) {
      return;
    }
    try {
      return options.timeToDisplayTracker.reportFullyDisplayed(
        spanId: spanId,
      );
    } catch (exception, stackTrace) {
      if (options.automatedTestMode) {
        rethrow;
      }
      options.log(
        SentryLevel.error,
        'Error while reporting TTFD',
        exception: exception,
        stackTrace: stackTrace,
      );
    }
  }
}

// lib/time_to_display_interactor.dart
//
// Full, self‑contained example that realises the Architecture C FSM.
// Dependencies: dart:async, sentry_flutter, span_recorder.dart,
//               screen_timing_event.dart (sealed events), root_txn_status.dart
//
// ────────────────────────────────────────────────────────────────────────────

/// Internal object that tracks one live transaction (route instance).
class _TxnState {
  _TxnState({
    required this.txn,
    required this.ttid,
    required this.ttidTimeout,
    // required this.ttfdTimeout,
    // required this.ttfd,
  });

  final ISentrySpan txn;
  final ISentrySpan ttid;
  // final ISentrySpan ttfd;

  final Timer ttidTimeout;
  // final Timer ttfdTimeout;

  bool get ttidFinished => ttid.finished;
  // bool get ttfdFinished => ttfd.finished;
}

late final interactor = TimeToDisplayInteractor(Sentry.currentHub);

/// Finite‑state machine that converts [ScreenTimingEvent]s into Sentry spans
/// & measurements.  Handles app‑start and navigation paths, early/late events,
/// timeouts, and aborts.
///
/// *Key invariants*
/// • at most **one** open transaction per SpanId
/// • TTFD end ≥ TTID end
/// • every open span eventually finishes (timeout or abort)
class TimeToDisplayInteractor {
  TimeToDisplayInteractor(this._hub, {TimeToDisplayManager? manager})
      : _manager = manager ?? TimeToDisplayManager(_hub);

  // ───────────────────────────  Fields  ────────────────────────────────────
  final Hub _hub;
  final TimeToDisplayManager _manager;

  AppStartTimingHandle? _appStartTimingHandle;

  AppStartTimingHandle? get appStartTimingHandle => _appStartTimingHandle;

  RouteTimingHandle? _routeTimingHandle;

  RouteTimingHandle? get routeTimingHandle => _routeTimingHandle;

  // tuning knobs
  /// Called by your bootstrap
  AppStartTimingHandle? startApp({
    required DateTime ts,
    required bool coldStart,
    required SpanId spanId,
  }) {
    _manager._startTransaction(
        routeName: 'root /', ts: ts, spanId: spanId, isRootScreen: true);
    final handle = AppStartTimingHandle._(spanId, this);
    _appStartTimingHandle = handle;
    return handle;
  }

  /// Called by your navigator observer
  RouteTimingHandle? startRoute({
    required String routeName,
    required DateTime ts,
    required SpanId spanId,
  }) {
    _manager._startTransaction(
        routeName: routeName, ts: ts, spanId: spanId, isRootScreen: false);
    final handle = RouteTimingHandle._(spanId, this);
    _routeTimingHandle = handle;
    return handle;
  }

  void endTtid(SpanId id, DateTime ts, bool isRootScreen) {
    _manager._finishTtid(id: id, ts: ts, isRootScreen: isRootScreen);
  }

  void _abortTxn({required SpanId id, required DateTime ts}) {
    // final st = _open[id];
    // if (st == null) return;

    // _finishTtid(id: id, ts: ts, deadline: true);
    // _finishTtfd(id: id, ts: ts, deadline: true);
  }
}

/// lifecycle control
class TimeToDisplayManager {
  TimeToDisplayManager(this._hub);

  final Hub _hub;

  _TxnState? _currentState;

  static const _ttidTimeoutDuration = Duration(seconds: 5);

  void _startTransaction({
    required String routeName,
    required DateTime ts,
    required SpanId spanId,
    required bool isRootScreen,
  }) {
    final transactionContext = SentryTransactionContext(
        routeName, SentrySpanOperations.uiLoad,
        transactionNameSource: SentryTransactionNameSource.component,
        origin: SentryTraceOrigins.autoNavigationRouteObserver,
        spanId: spanId);

    final transaction = _hub.startTransactionWithContext(
      transactionContext,
      startTimestamp: ts,
      bindToScope: true,
      waitForChildren: true,
      autoFinishAfter: Duration(seconds: 3),
      trimEnd: true,
    );

    final ttidSpan = transaction.startChild(
        SentrySpanOperations.uiTimeToInitialDisplay,
        startTimestamp: ts);
    final ttidTimeout = Timer(_ttidTimeoutDuration, () {
      assert(() {
        print(
            'TTID timeout reached for $spanId - this is unusual and should be investigated');
        return true;
      }());
      _finishTtid(
          id: spanId,
          ts: _hub.options.clock(),
          finishedByTimeout: true,
          isRootScreen: isRootScreen);
    });

    // log: starting a new transaction
    // log: if _currentState is not null log that we are transitioning
    _currentState =
        _TxnState(txn: transaction, ttid: ttidSpan, ttidTimeout: ttidTimeout);
  }

  void _finishTtid({
    required SpanId id,
    required DateTime ts,
    required bool isRootScreen,
    bool finishedByTimeout = false,
  }) {
    assert(_currentState != null, 'No Time To Display transaction in progress');

    final ttidSpan = _currentState?.ttid;
    if (ttidSpan == null || ttidSpan.finished) return;
    if (id != _currentState?.txn.context.spanId) return;

    ttidSpan.finish(
      endTimestamp: ts,
      status:
          finishedByTimeout ? SpanStatus.deadlineExceeded() : SpanStatus.ok(),
    );
    _currentState?.ttidTimeout.cancel();
    _currentState?.txn.setMeasurement(
      'time_to_initial_display',
      ts.difference(ttidSpan.startTimestamp).inMilliseconds.toDouble(),
    );
  }

  void clear() {
    _currentState?.ttidTimeout.cancel();
    _currentState = null;
  }
}

/// Only for the root app‑start transaction.
@immutable
final class AppStartTimingHandle {
  const AppStartTimingHandle._(this._spanId, this._interactor);

  final SpanId _spanId;
  final TimeToDisplayInteractor _interactor;

  void endTtid(DateTime ts) => _interactor.endTtid(_spanId, ts, true);

  // void reportFullyDisplayed(DateTime ts) =>
  //     _interactor.dispatch(FullDisplayReported(spanId: _spanId, ts: ts));
}

/// For normal route‑push transactions.
@immutable
final class RouteTimingHandle {
  const RouteTimingHandle._(this._spanId, this._interactor);

  final SpanId _spanId;
  final TimeToDisplayInteractor _interactor;

  void endTtid(DateTime ts) => _interactor.endTtid(_spanId, ts, false);

  // void reportFullyDisplayed(DateTime ts) =>
  //     _interactor._dispatch(FullDisplayReported(spanId: _spanId, ts: ts));
}
