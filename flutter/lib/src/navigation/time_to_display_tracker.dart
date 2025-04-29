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

  ISentrySpan? _currentTransaction;

  /// Returns the current transaction being tracked by the [TimeToDisplayTracker].
  /// This can be used to report full display for the current route.
  ISentrySpan? get currentTransaction => _currentTransaction;

  Future<void> track(
    ISentrySpan transaction, {
    DateTime? endTimestamp,
  }) async {
    if (transaction is! SentryTracer) {
      return;
    }
    _currentTransaction = transaction;

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

  @internal
  Future<void> reportFullyDisplayed({SpanId? spanId}) async {
    if (options.enableTimeToFullDisplayTracing) {
      return _ttfdTracker.reportFullyDisplayed(spanId: spanId);
    }
  }

  // Cancel unfinished TTID/TTFD spans, e.g this might happen if the user navigates
  // away from the current route before TTFD or TTID is finished.
  @internal
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
    _currentTransaction = null;

    _ttidTracker.clear();
    if (options.enableTimeToFullDisplayTracing) {
      _ttfdTracker.clear();
    }
  }
}
