import 'dart:async';

import '../../sentry_flutter.dart';

class TimeToDisplayManager {
  TimeToDisplayManager(this._hub);

  final Hub _hub;

  _TxnState? _currentState;

  static const _ttidTimeoutDuration = Duration(seconds: 5);

  void startTransaction({
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
      finishTtid(
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

  void finishTtid({
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

  void abortTransaction({
    required DateTime ts,
  }) {
    if (_currentState == null) return;

    _currentState?.ttid.finish(
      endTimestamp: ts,
      status: SpanStatus.cancelled(),
    );
    _currentState?.ttidTimeout.cancel();

    _currentState?.txn.finish(
      endTimestamp: ts,
      status: SpanStatus.cancelled(),
    );

    _hub.scope.span = null;
    _currentState?.txn.finish(endTimestamp: ts);

    _currentState = null;
  }

  void clear() {
    _currentState?.ttidTimeout.cancel();
    _currentState = null;
  }
}

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
