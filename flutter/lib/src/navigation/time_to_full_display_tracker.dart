// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:meta/meta.dart';
// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';
import '../../sentry_flutter.dart';

@internal
class TimeToFullDisplayTracker {
  TimeToFullDisplayTracker(this._autoFinishAfter);

  final Duration _autoFinishAfter;

  SpanId? _parentSpanId;
  Completer<DateTime?>? _trackingCompleter;

  Future<void> track({
    required SentryTracer transaction,
    DateTime? ttidEndTimestamp,
    DateTime? ttfdEndTimestamp,
  }) async {
    _parentSpanId = transaction.context.spanId;

    final ttfdSpan = transaction.startChild(
      SentrySpanOperations.uiTimeToFullDisplay,
      description: '${transaction.name} full display',
      startTimestamp: transaction.startTimestamp,
    );
    ttfdSpan.origin = SentryTraceOrigins.manualUiTimeToDisplay;

    final determinedEndTimestamp =
        ttfdEndTimestamp ?? await _determineEndTime();
    final fallbackEndTimestamp = ttidEndTimestamp ?? getUtcDateTime();
    final endTimestamp = determinedEndTimestamp ?? fallbackEndTimestamp;

    // If a timestamp is provided, the operation was successful; otherwise, it timed out
    final status = determinedEndTimestamp != null
        ? SpanStatus.ok()
        : SpanStatus.deadlineExceeded();

    // Should only add measurements if the span is successful
    if (status == SpanStatus.ok()) {
      final ttfdMeasurement = SentryMeasurement.timeToFullDisplay(
        endTimestamp.difference(ttfdSpan.startTimestamp),
      );
      transaction.setMeasurement(
        ttfdMeasurement.name,
        ttfdMeasurement.value,
        unit: ttfdMeasurement.unit,
      );
    }

    await ttfdSpan.finish(
      status: status,
      endTimestamp: endTimestamp,
    );
  }

  FutureOr<DateTime?> _determineEndTime() {
    _trackingCompleter = Completer<DateTime?>();
    return _trackingCompleter?.future.timeout(
      _autoFinishAfter,
      onTimeout: () => Future.value(null),
    );
  }

  Future<bool> reportFullyDisplayed(
      {SpanId? spanId, DateTime? endTimestamp}) async {
    final startSpanId = _parentSpanId;
    final endSpanId = spanId;

    if (startSpanId != null && endSpanId != null && startSpanId != endSpanId) {
      return true; // Called on unrelated transaction, ignore.
    }
    if (_trackingCompleter != null) {
      if (!_trackingCompleter!.isCompleted) {
        _trackingCompleter?.complete(endTimestamp ?? getUtcDateTime());
      }
      return true;
    } else {
      return false; // Called before track was called.
    }
  }

  void clear() {
    _parentSpanId = null;
    _trackingCompleter = null;
  }
}
