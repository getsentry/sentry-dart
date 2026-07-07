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
  SentryTransactionContext? _appStartContext;

  // The timestamp where report TTFD was called before the transaction was started.
  DateTime? get pendingTTFDEndTimestamp => _pendingTTFDEndTimestamp;

  void prepareAppStart() {
    _appStartContext = _createAppStartContext();
    transactionId = _appStartContext!.spanId;
  }

  /// Tracks the initial native app-start display transaction.
  ///
  /// If provided, [attachAppStart] is awaited after the `ui.load` transaction
  /// exists and before TTID/TTFD tracking starts. Attached app-start
  /// measurements must be written in that window because a child span can
  /// finish the wait-for-children transaction, after which measurements can no
  /// longer be added.
  Future<void> trackAppStart({
    required DateTime startTimestamp,
    required DateTime ttidEndTimestamp,
    Future<void> Function(SentryTracer transaction)? attachAppStart,
  }) async {
    final context = _appStartContext ?? _createAppStartContext();
    _appStartContext = null;

    final transaction = _hub.startTransactionWithContext(
      context,
      startTimestamp: startTimestamp,
      waitForChildren: true,
      autoFinishAfter: const Duration(seconds: 3),
      bindToScope: true,
      trimEnd: true,
    );
    if (transaction is! SentryTracer) {
      return;
    }

    await attachAppStart?.call(transaction);
    await track(transaction, ttidEndTimestamp: ttidEndTimestamp);
  }

  SentryTransactionContext _createAppStartContext() {
    return SentryTransactionContext(
      'root /',
      SentrySpanOperations.uiLoad,
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
    transactionId = null;
    _pendingTTFDEndTimestamp = null;
    _appStartContext = null;

    _ttidTracker.clear();
    if (options.enableTimeToFullDisplayTracing) {
      _ttfdTracker.clear();
    }
  }
}
