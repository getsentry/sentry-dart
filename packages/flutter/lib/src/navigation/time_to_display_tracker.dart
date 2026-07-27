// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'root_route.dart';
import 'time_to_full_display_tracker.dart';
import 'time_to_initial_display_tracker.dart';
// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';
// ignore: implementation_imports
import 'package:sentry/src/utils/iterable_utils.dart';

@internal
class TimeToDisplayTracker {
  final Hub _hub;
  final TimeToInitialDisplayTracker _ttidTracker;
  final TimeToFullDisplayTracker _ttfdTracker;
  final SentryFlutterOptions options;

  TimeToDisplayTracker({
    Hub? hub,
    TimeToInitialDisplayTracker? ttidTracker,
    TimeToFullDisplayTracker? ttfdTracker,
    required this.options,
  })  : _hub = hub ?? HubAdapter(),
        _ttidTracker = ttidTracker ?? TimeToInitialDisplayTracker(),
        _ttfdTracker = ttfdTracker ??
            TimeToFullDisplayTracker(
              Duration(seconds: 30),
            );

  // The id of the currently tracked transaction
  SpanId? transactionId;

  DateTime? _pendingTTFDEndTimestamp;
  _PreparedInitialDisplay? _prepared;

  // The timestamp where report TTFD was called before the transaction was started.
  DateTime? get pendingTTFDEndTimestamp => _pendingTTFDEndTimestamp;

  /// Reserves the initial standalone `ui.load` identity for the app start.
  ///
  /// Only the identity: [recordInitialDisplay] starts the transaction. Starting
  /// it here would arm its idle timer before a first frame exists, and a start
  /// slower than that timer drops the childless root along with TTID and TTFD.
  void prepareInitialDisplay(DateTime startTimestamp) {
    final context = initialDisplayTransactionContext();
    transactionId = context.spanId;
    _prepared = _PreparedInitialDisplay(context, startTimestamp);
  }

  /// Whether a prepared app start is still waiting for its first route name.
  bool get isAppStartRoutePending => _prepared?.isRouteNamePending ?? false;

  /// Names the reserved app-start root after the first rendered route.
  ///
  /// Only the first call takes effect, so a later initial push — a nested
  /// navigator, for instance — is still treated as ordinary navigation.
  void setAppStartRouteName(String? routeName) {
    final prepared = _prepared;
    if (prepared == null || !prepared.isRouteNamePending) return;

    prepared.isRouteNamePending = false;
    prepared.context.name = resolveRouteDisplayName(routeName);
  }

  /// Starts the reserved initial standalone display root and records TTID/TTFD.
  Future<void> recordInitialDisplay(DateTime endTimestamp) async {
    final prepared = _prepared;
    _prepared = null;
    if (prepared == null) {
      return;
    }

    final transaction = _hub.startTransactionWithContext(
      prepared.context,
      startTimestamp: prepared.startTimestamp,
      waitForChildren: true,
      autoFinishAfter: const Duration(seconds: 3),
      bindToScope: true,
      trimEnd: true,
    );
    await track(transaction, ttidEndTimestamp: endTimestamp);
  }

  Future<void> track(
    ISentrySpan transaction, {
    DateTime? ttidEndTimestamp,
  }) async {
    if (transaction is! SentryTracer) {
      return;
    }
    if (transactionId != transaction.context.spanId) {
      _pendingTTFDEndTimestamp = null;
    }
    transactionId = transaction.context.spanId;

    // TTID
    final ttidSpan = await _ttidTracker.track(
      transaction: transaction,
      endTimestamp: ttidEndTimestamp,
    );

    // TTFD
    if (options.enableTimeToFullDisplayTracing) {
      final ttidEndTimestamp = ttidSpan?.endTimestamp;
      final pendingTTFDEndTimestamp = _pendingTTFDEndTimestamp;
      DateTime? ttfdEndTimestamp;
      if (pendingTTFDEndTimestamp != null) {
        ttfdEndTimestamp = pendingTTFDEndTimestamp;
        if (ttidEndTimestamp != null &&
            ttfdEndTimestamp.isBefore(ttidEndTimestamp)) {
          ttfdEndTimestamp = ttidEndTimestamp;
        }
      }

      await _ttfdTracker.track(
        transaction: transaction,
        ttidEndTimestamp: ttidEndTimestamp,
        ttfdEndTimestamp: ttfdEndTimestamp,
      );
    }
  }

  Future<void> reportFullyDisplayed(
      {SpanId? spanId, DateTime? endTimestamp}) async {
    if (options.enableTimeToFullDisplayTracing) {
      final reported = await _ttfdTracker.reportFullyDisplayed(
        spanId: spanId,
        endTimestamp: endTimestamp,
      );

      if (!reported && spanId == transactionId) {
        _pendingTTFDEndTimestamp = endTimestamp ?? DateTime.now();
      }
    }
  }

  // Cancel unfinished TTID/TTFD spans, e.g this might happen if the user navigates
  // away from the current route before TTFD or TTID is finished.
  Future<void> cancelUnfinishedSpans(
      SentryTracer transaction, DateTime endTimestamp) async {
    final ttidSpan = transaction.children.firstWhereOrNull(
      (child) =>
          child.context.operation ==
          SentrySpanOperations.uiTimeToInitialDisplay,
    );
    final ttfdSpan = transaction.children.firstWhereOrNull(
      (child) =>
          child.context.operation == SentrySpanOperations.uiTimeToFullDisplay,
    );

    if (ttidSpan != null && !ttidSpan.finished) {
      await ttidSpan.finish(
        status: SpanStatus.deadlineExceeded(),
        endTimestamp: endTimestamp,
      );
    }

    if (ttfdSpan != null && !ttfdSpan.finished) {
      await ttfdSpan.finish(
        status: SpanStatus.deadlineExceeded(),
        endTimestamp: ttidSpan?.endTimestamp ?? endTimestamp,
      );
    }
  }

  void clear() {
    // Only an identity was reserved, so there is no root to tear down.
    _prepared = null;
    transactionId = null;
    _pendingTTFDEndTimestamp = null;
    _ttidTracker.clear();
    if (options.enableTimeToFullDisplayTracing) {
      _ttfdTracker.clear();
    }
  }
}

/// An initial standalone `ui.load` root reserved but not yet started.
final class _PreparedInitialDisplay {
  _PreparedInitialDisplay(this.context, this.startTimestamp);

  final SentryTransactionContext context;
  final DateTime startTimestamp;

  /// Cleared once the first rendered route has named [context].
  bool isRouteNamePending = true;
}
