import 'dart:async';

// ignore_for_file: invalid_use_of_internal_member
// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry/sentry.dart';

import '../../sentry_flutter.dart';
import 'display_txn.dart';

typedef Clock = DateTime Function();
typedef Logger = void Function(
  Object message, {
  Object? exception,
  StackTrace? stackTrace,
});

/// Core engine for display transactions (V2).
///
/// Manages per-slot state, timers, and legal transitions for TTID/TTFD.
class DisplayTransactionEngine {
  DisplayTransactionEngine({
    required Hub hub,
    required SentryFlutterOptions options,
    Clock? clock,
    Duration? defaultAutoFinishAfter,
    Logger? logger,
  })  : _hub = hub,
        _clock = clock ?? DateTime.now,
        _defaultAutoFinishAfter =
            defaultAutoFinishAfter ?? const Duration(seconds: 30),
        _log = logger ?? _noopLogger;

  final Hub _hub;
  // Clock and configuration
  final Clock _clock;
  final Duration _defaultAutoFinishAfter;
  final Logger _log;

  static void _noopLogger(Object message,
      {Object? exception, StackTrace? stackTrace}) {}

  // Maintain two explicit state fields (root and route) instead of a map.
  DisplayState _rootState = const Idle();
  DisplayState _routeState = const Idle();

  DisplayState _getState(DisplaySlot slot) =>
      slot == DisplaySlot.root ? _rootState : _routeState;

  void _setState(DisplaySlot slot, DisplayState state) {
    if (slot == DisplaySlot.root) {
      _rootState = state;
    } else {
      _routeState = state;
    }
  }

  /// Starts a new display transaction on [slot], aborting any previous one.
  DisplayTxn start({
    required DisplaySlot slot,
    required String name,
    Object? arguments,
    required DateTime now,
    Duration? autoFinishAfter,
  }) {
    final current = _getState(slot);
    if (current is Active) {
      // Auto-abort previous as per policy.
      _log(
        'start(): Auto-aborting previous transaction on $slot (name=${current.txn.name})',
      );
      abort(slot: slot, when: now);
    }

    // Create a transaction context based on slot/name
    final context = _transactionContextFor(slot: slot, name: name);

    // Keep variable removal to satisfy lints (not currently used).
    // Start transaction via Hub
    final root = _hub.startTransactionWithContext(
      context,
      startTimestamp: now,
      waitForChildren: true,
      autoFinishAfter: autoFinishAfter ?? _defaultAutoFinishAfter,
      trimEnd: true,
      onFinish: (t) {},
    );

    if (root is! SentryTracer) {
      // Not sampled or disabled; keep engine idle for this slot.
      _log('start(): No tracer (not sampled?) for $slot:$name.');
      return DisplayTxn(
        slot: slot,
        name: name,
        arguments: arguments,
        transaction: SentryTracer(
          context,
          _hub,
          startTimestamp: now,
        ),
        startedAt: now,
        autoFinishAfter: autoFinishAfter ?? _defaultAutoFinishAfter,
      );
    }

    // Attach route arguments if provided
    if (arguments != null) {
      root.setData('route_settings_arguments', arguments);
    }

    // Bind transaction to scope only if no active span is set
    _hub.configureScope((scope) {
      scope.span ??= root;
    });

    final txn = DisplayTxn(
      slot: slot,
      name: name,
      arguments: arguments,
      transaction: root,
      startedAt: now,
      autoFinishAfter: autoFinishAfter ?? _defaultAutoFinishAfter,
    );

    // Schedule TTFD timeout
    txn.timeoutTimer = Timer(txn.autoFinishAfter, () {
      try {
        final deadline = _clock();
        // If TTFD didn't finish in time, force-finish it.
        finishTtfd(slot: slot, when: deadline, dueToTimeout: true);
      } catch (e, st) {
        _log('Timeout handler threw', exception: e, stackTrace: st);
      }
    });

    _setState(slot, Active(txn: txn, ttidOpen: true));
    return txn;
  }

  /// Marks TTID as finished for the given [slot].
  void finishTtid({
    required DisplaySlot slot,
    required DateTime when,
  }) {
    final s = _getState(slot);
    switch (s) {
      case Idle():
        _log('finishTtid(): No active transaction for $slot. Ignoring.');
        return;
      case Finished():
        _log('finishTtid(): Already finished for $slot. Ignoring.');
        return;
      case Aborted():
        _log('finishTtid(): Already aborted for $slot. Ignoring.');
        return;
      case Active(txn: final txn, ttidOpen: final ttidOpen):
        if (!ttidOpen) {
          // idempotent
          return;
        }
        // Create TTID span if needed and finish it
        final tracer = txn.transaction;
        txn.ttidSpan ??= tracer.startChild(
          SentrySpanOperations.uiTimeToInitialDisplay,
          description: '${txn.name} initial display',
          startTimestamp: tracer.startTimestamp,
        )..origin = SentryTraceOrigins.autoUiTimeToDisplay;

        final ttidSpan = txn.ttidSpan!;
        // Add TTID measurement on transaction
        final ttidMeasurement = SentryMeasurement.timeToInitialDisplay(
          when.difference(tracer.startTimestamp),
        );
        tracer.setMeasurement(
          ttidMeasurement.name,
          ttidMeasurement.value,
          unit: ttidMeasurement.unit,
        );
        ttidSpan.finish(status: SpanStatus.ok(), endTimestamp: when);
        txn.ttidEndedAt = when;

        final pending = txn.pendingTtfdBeforeTtid;
        if (pending != null) {
          // If pending TTFD end is before TTID end, clamp to TTID.
          final ttfdEnd = pending.isBefore(when) ? when : pending;
          // Will finish the transaction entirely.
          _finishTtfdInternal(slot: slot, txn: txn, when: ttfdEnd);
          return;
        }

        // Keep active but TTID is now closed.
        _setState(slot, Active(txn: txn, ttidOpen: false));
    }
  }

  /// Marks TTFD as finished for the given [slot].
  void finishTtfd({
    required DisplaySlot slot,
    required DateTime when,
    bool dueToTimeout = false,
  }) {
    final s = _getState(slot);
    switch (s) {
      case Idle():
        _log('finishTtfd(): No active transaction for $slot. Ignoring.');
        return;
      case Finished():
        // idempotent
        return;
      case Aborted():
        // ignore
        return;
      case Active(txn: final txn, ttidOpen: final ttidOpen):
        if (ttidOpen) {
          if (dueToTimeout) {
            // Timeout forces completion even if TTID didn't end yet.
            // End TTID span with deadlineExceeded
            final tracer = txn.transaction;
            txn.ttidSpan ??= tracer.startChild(
              SentrySpanOperations.uiTimeToInitialDisplay,
              description: '${txn.name} initial display',
              startTimestamp: tracer.startTimestamp,
            )..origin = SentryTraceOrigins.autoUiTimeToDisplay;

            // Add TTID measurement even in timeout (same as legacy)
            final ttidMeasurement = SentryMeasurement.timeToInitialDisplay(
              when.difference(tracer.startTimestamp),
            );
            tracer.setMeasurement(
              ttidMeasurement.name,
              ttidMeasurement.value,
              unit: ttidMeasurement.unit,
            );

            txn.ttidSpan!.finish(
              status: SpanStatus.deadlineExceeded(),
              endTimestamp: when,
            );
            txn.ttidEndedAt = when;
            _finishTtfdInternal(
                slot: slot, txn: txn, when: when, dueToTimeout: true);
            return;
          } else {
            // TTID not yet finished; store pending TTFD.
            txn.pendingTtfdBeforeTtid = when;
            return;
          }
        }
        _finishTtfdInternal(slot: slot, txn: txn, when: when);
    }
  }

  /// Aborts the active transaction for [slot].
  void abort({
    required DisplaySlot slot,
    required DateTime when,
  }) {
    final s = _getState(slot);
    switch (s) {
      case Idle():
        // nothing to abort
        return;
      case Finished():
        // nothing to abort
        return;
      case Aborted():
        // already aborted
        return;
      case Active(txn: final txn, ttidOpen: final ttidOpen):
        _cancelTimeout(txn);
        final tracer = txn.transaction;
        // Ensure TTID span is finished
        if (ttidOpen) {
          txn.ttidSpan ??= tracer.startChild(
            SentrySpanOperations.uiTimeToInitialDisplay,
            description: '${txn.name} initial display',
            startTimestamp: tracer.startTimestamp,
          )..origin = SentryTraceOrigins.autoUiTimeToDisplay;

          final ttidMeasurement = SentryMeasurement.timeToInitialDisplay(
            when.difference(tracer.startTimestamp),
          );
          tracer.setMeasurement(
            ttidMeasurement.name,
            ttidMeasurement.value,
            unit: ttidMeasurement.unit,
          );
          txn.ttidSpan!.finish(
            status: SpanStatus.deadlineExceeded(),
            endTimestamp: when,
          );
          txn.ttidEndedAt = when; // TTID ends with deadline exceeded semantics
        }
        // Ensure TTFD end is set and not before TTID end.
        final ttfdEnd = _maxDate(when, txn.ttidEndedAt ?? when);
        _finishTtfdInternal(
          slot: slot,
          txn: txn,
          when: ttfdEnd,
          aborted: true,
        );
    }
  }

  /// Returns a snapshot of both slots.
  ({DisplayState root, DisplayState route}) snapshot() => (
        root: _rootState,
        route: _routeState,
      );

  void _finishTtfdInternal({
    required DisplaySlot slot,
    required DisplayTxn txn,
    required DateTime when,
    bool dueToTimeout = false,
    bool aborted = false,
  }) {
    if (txn.ttfdEndedAt != null) {
      // idempotent
      return;
    }
    _cancelTimeout(txn);
    txn.ttfdEndedAt = when;

    // Create TTFD span if needed and finish it
    final tracer = txn.transaction;
    txn.ttfdSpan ??= tracer.startChild(
      SentrySpanOperations.uiTimeToFullDisplay,
      description: '${txn.name} full display',
      startTimestamp: tracer.startTimestamp,
    )..origin = SentryTraceOrigins.manualUiTimeToDisplay;

    // Add TTFD measurement
    final ttfdMeasurement = SentryMeasurement.timeToFullDisplay(
      when.difference(tracer.startTimestamp),
    );
    tracer.setMeasurement(
      ttfdMeasurement.name,
      ttfdMeasurement.value,
      unit: ttfdMeasurement.unit,
    );

    final status = (dueToTimeout || aborted)
        ? SpanStatus.deadlineExceeded()
        : SpanStatus.ok();
    txn.ttfdSpan!.finish(status: status, endTimestamp: when);

    // Finish the transaction itself at TTFD end
    tracer.finish(endTimestamp: when);

    _setState(slot, Finished(txn: txn));
  }

  SentryTransactionContext _transactionContextFor({
    required DisplaySlot slot,
    required String name,
  }) {
    return SentryTransactionContext(
      name,
      SentrySpanOperations.uiLoad,
      transactionNameSource: SentryTransactionNameSource.component,
      origin: slot == DisplaySlot.root
          ? SentryTraceOrigins.autoUiTimeToDisplay
          : SentryTraceOrigins.autoNavigationRouteObserver,
    );
  }

  void _cancelTimeout(DisplayTxn txn) {
    final t = txn.timeoutTimer;
    if (t != null) {
      try {
        t.cancel();
      } catch (_) {}
      txn.timeoutTimer = null;
    }
  }

  DateTime _maxDate(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
}
