// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
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
  SentryTracer? _preparedInitialDisplay;

  // The timestamp where report TTFD was called before the transaction was started.
  DateTime? get pendingTTFDEndTimestamp => _pendingTTFDEndTimestamp;

  /// Creates and retains the initial standalone `ui.load` transaction.
  void prepareInitialDisplay(DateTime startTimestamp) {
    final context = _createInitialDisplayContext();
    transactionId = context.spanId;
    final transaction = _hub.startTransactionWithContext(
      context,
      startTimestamp: startTimestamp,
      waitForChildren: true,
      autoFinishAfter: const Duration(seconds: 3),
      bindToScope: true,
      trimEnd: true,
    );
    _preparedInitialDisplay = transaction is SentryTracer ? transaction : null;
  }

  /// Records TTID/TTFD on the retained initial standalone display root.
  Future<void> recordInitialDisplay(DateTime endTimestamp) async {
    final transaction = _preparedInitialDisplay;
    _preparedInitialDisplay = null;
    if (transaction != null) {
      await track(transaction, ttidEndTimestamp: endTimestamp);
    }
  }

  SentryTransactionContext _createInitialDisplayContext() {
    return SentryTransactionContext(
      'root /',
      SentrySpanOperations.uiLoad,
      transactionNameSource: SentryTransactionNameSource.component,
      origin: SentryTraceOrigins.autoUiTimeToDisplay,
    );
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
    // Drop the prepared root reference only. Idle auto-finish (and the
    // childless-idle drop in SentryTracer) owns teardown without capture.
    _preparedInitialDisplay = null;
    transactionId = null;
    _pendingTTFDEndTimestamp = null;
    _ttidTracker.clear();
    if (options.enableTimeToFullDisplayTracing) {
      _ttfdTracker.clear();
    }
  }
}
