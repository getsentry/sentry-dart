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

  // The id of the root transaction created in [NativeAppStartIntegration]
  SpanId? rootTransactionId;

  // The end timestamp of the root transaction. Used in [NativeAppStartHandler]
  DateTime? rootTransactionEndTimestamp;

  Future<void> track(
    ISentrySpan transaction, {
    DateTime? endTimestamp,
  }) async {
    if (transaction is! SentryTracer) {
      return;
    }
    transactionId = transaction.context.spanId;

    // TTID
    final ttidSpan = await _ttidTracker.track(
      transaction: transaction,
      endTimestamp: endTimestamp,
    );

    // TTFD
    if (options.enableTimeToFullDisplayTracing) {
      await _ttfdTracker.track(
        transaction: transaction,
        ttidEndTimestamp: ttidSpan?.endTimestamp,
      );
    }
  }

  Future<void> reportFullyDisplayed(
      {SpanId? spanId, DateTime? endTimestamp}) async {
    if (options.enableTimeToFullDisplayTracing) {
      // Special case for root transaction
      if (rootTransactionId != null && rootTransactionId == spanId) {
        rootTransactionEndTimestamp = endTimestamp ?? DateTime.now();
      }
      return _ttfdTracker.reportFullyDisplayed(
          spanId: spanId, endTimestamp: endTimestamp);
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
    clear();
  }

  void clear() {
    transactionId = null;

    _ttidTracker.clear();
    if (options.enableTimeToFullDisplayTracing) {
      _ttfdTracker.clear();
    }
  }
}
