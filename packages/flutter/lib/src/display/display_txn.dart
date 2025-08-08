import 'dart:async';
// ignore_for_file: invalid_use_of_internal_member
// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry/sentry.dart';

/// Identifies which logical slot a display transaction belongs to.
///
/// - root: App start transaction
/// - route: Per-navigation transaction
enum DisplaySlot { root, route }

/// Small value object for a time window. `end` may be null while open.
typedef TimeRange = ({DateTime start, DateTime? end});

/// Holds all mutable data for a single display transaction lifecycle.
///
/// The engine owns instances of this class and transitions their [DisplayState].
class DisplayTxn {
  DisplayTxn({
    required this.slot,
    required this.name,
    required this.arguments,
    required this.transaction,
    required this.startedAt,
    required this.autoFinishAfter,
  });

  /// Whether this is the app-start (root) or a route transaction.
  final DisplaySlot slot;

  /// Human-readable name, e.g., 'root /' or a route name.
  final String name;

  /// Optional route arguments associated with the start.
  final Object? arguments;

  /// The top-level transaction span.
  final SentryTracer transaction;

  /// The TTID child span (ui.time_to_initial_display), if created.
  ISentrySpan? ttidSpan;

  /// The TTFD child span (ui.time_to_full_display), if created.
  ISentrySpan? ttfdSpan;

  /// Transaction start timestamp.
  final DateTime startedAt;

  /// When TTID ended. If null, TTID is still considered open.
  DateTime? ttidEndedAt;

  /// When TTFD ended. If null, TTFD is still considered open.
  DateTime? ttfdEndedAt;

  /// A pending TTFD timestamp that happened before TTID closed.
  DateTime? pendingTtfdBeforeTtid;

  /// Auto-finish timeout configuration for TTFD/end of transaction.
  final Duration autoFinishAfter;

  /// Internal timer used by the engine to enforce auto-finish.
  Timer? timeoutTimer;

  /// Convenience: Returns true if TTID span has not been ended yet.
  bool get isTtidOpen => ttidEndedAt == null;

  /// Returns a snapshot of the TTID window.
  TimeRange get ttidWindow => (start: startedAt, end: ttidEndedAt);

  /// Returns a snapshot of the TTFD window.
  TimeRange get ttfdWindow => (
        start: ttidEndedAt ?? startedAt,
        end: ttfdEndedAt,
      );
}

/// Sealed state machine for a display transaction.
///
/// Legal transitions:
/// Idle → Active(ttidOpen: true) → Active(ttidOpen: false) → Finished
///                                   └──────────────┬──────────────→ Aborted
sealed class DisplayState {
  const DisplayState();
}

/// No active display transaction.
final class Idle extends DisplayState {
  const Idle();
}

/// Active display transaction. [txn] owns all mutable data.
final class Active extends DisplayState {
  const Active({required this.txn, required this.ttidOpen});

  final DisplayTxn txn;
  final bool ttidOpen;
}

/// Finished display transaction (normal completion or due to timeout).
final class Finished extends DisplayState {
  const Finished({required this.txn});

  final DisplayTxn txn;
}

/// Aborted display transaction (e.g., route popped before TTID/TTFD).
final class Aborted extends DisplayState {
  const Aborted({required this.txn});

  final DisplayTxn txn;
}
