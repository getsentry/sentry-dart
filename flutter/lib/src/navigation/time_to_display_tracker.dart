// ignore_for_file: invalid_use_of_internal_member

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'time_to_full_display_tracker.dart';
import 'time_to_initial_display_tracker.dart';
// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';

@internal
class TimeToDisplayTracker {
  final TimeToInitialDisplayTracker _ttidTracker;
  final TimeToFullDisplayTracker _ttfdTracker;
  final SentryFlutterOptions options;

  TimeToDisplayTracker({
    TimeToInitialDisplayTracker? ttidTracker,
    TimeToFullDisplayTracker? ttfdTracker,
    required this.options,
  })  : _ttidTracker = ttidTracker ?? TimeToInitialDisplayTracker(),
        _ttfdTracker = ttfdTracker ??
            TimeToFullDisplayTracker(
              Duration(seconds: 30),
            );

  // The id of the currently tracked transaction
  SpanId? transactionId;

  DateTime? _pendingTTFDEndTimestamp;

  // The timestamp where report TTFD was called before the transaction was started.
  DateTime? get pendingTTFDEndTimestamp => _pendingTTFDEndTimestamp;

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
    final ttidSpan = transaction.children.firstWhereOrNull((child) =>
        child.context.operation == SentrySpanOperations.uiTimeToInitialDisplay);
    final ttfdSpan = transaction.children.firstWhereOrNull((child) =>
        child.context.operation == SentrySpanOperations.uiTimeToFullDisplay);

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
    transactionId = null;
    _pendingTTFDEndTimestamp = null;

    _ttidTracker.clear();
    if (options.enableTimeToFullDisplayTracing) {
      _ttfdTracker.clear();
    }
  }
}
