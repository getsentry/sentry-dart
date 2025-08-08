import 'dart:async';

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
    required Object hub,
    required Object options,
    Clock? clock,
    Duration? defaultAutoFinishAfter,
    Logger? logger,
  })  : _clock = clock ?? DateTime.now,
        _defaultAutoFinishAfter =
            defaultAutoFinishAfter ?? const Duration(seconds: 30),
        _log = logger ?? _noopLogger;

  // Reserved for future use when wiring to real Hub/Options. Not stored until used.
  final Clock _clock;
  final Duration _defaultAutoFinishAfter;
  final Logger _log;

  static void _noopLogger(Object message,
      {Object? exception, StackTrace? stackTrace}) {}

  final Map<DisplaySlot, DisplayState> _state = {
    DisplaySlot.root: const Idle(),
    DisplaySlot.route: const Idle(),
  };

  /// Starts a new display transaction on [slot], aborting any previous one.
  DisplayTxn start({
    required DisplaySlot slot,
    required String name,
    Object? arguments,
    required DateTime now,
    Duration? autoFinishAfter,
  }) {
    final current = _state[slot];
    if (current is Active) {
      // Auto-abort previous as per policy.
      _log(
        'start(): Auto-aborting previous transaction on $slot (name=${current.txn.name})',
      );
      abort(slot: slot, when: now);
    }

    final txn = DisplayTxn(
      slot: slot,
      name: name,
      arguments: arguments,
      transaction:
          Object(), // real transaction will be attached in controller wiring
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

    _state[slot] = Active(txn: txn, ttidOpen: true);
    return txn;
  }

  /// Marks TTID as finished for the given [slot].
  void finishTtid({
    required DisplaySlot slot,
    required DateTime when,
  }) {
    final s = _state[slot];
    switch (s) {
      case null:
        _state[slot] = const Idle();
        return;
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
        _state[slot] = Active(txn: txn, ttidOpen: false);
    }
  }

  /// Marks TTFD as finished for the given [slot].
  void finishTtfd({
    required DisplaySlot slot,
    required DateTime when,
    bool dueToTimeout = false,
  }) {
    final s = _state[slot];
    switch (s) {
      case null:
        _state[slot] = const Idle();
        return;
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
            txn.ttidEndedAt = when;
            _finishTtfdInternal(slot: slot, txn: txn, when: when);
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
    final s = _state[slot];
    switch (s) {
      case null:
        _state[slot] = const Idle();
        return;
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
        if (ttidOpen) {
          txn.ttidEndedAt = when; // TTID ends with deadline exceeded semantics
        }
        // Ensure TTFD end is set and not before TTID end.
        final ttfdEnd = _maxDate(when, txn.ttidEndedAt ?? when);
        txn.ttfdEndedAt = ttfdEnd;
        _state[slot] = Aborted(txn: txn);
    }
  }

  /// Returns a snapshot of both slots.
  ({DisplayState root, DisplayState route}) snapshot() => (
        root: _state[DisplaySlot.root]!,
        route: _state[DisplaySlot.route]!,
      );

  void _finishTtfdInternal({
    required DisplaySlot slot,
    required DisplayTxn txn,
    required DateTime when,
  }) {
    if (txn.ttfdEndedAt != null) {
      // idempotent
      return;
    }
    _cancelTimeout(txn);
    txn.ttfdEndedAt = when;
    _state[slot] = Finished(txn: txn);
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
