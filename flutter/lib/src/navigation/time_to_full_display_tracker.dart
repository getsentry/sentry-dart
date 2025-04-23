// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:meta/meta.dart';
// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';
import '../../sentry_flutter.dart';

@internal
class TimeToFullDisplayTracker {
  TimeToFullDisplayTracker(
    this._options,
    this._endTimestampProvider, {
    Duration autoFinishAfter = const Duration(seconds: 30),
  }) : _autoFinishAfter = autoFinishAfter;

  final SentryOptions _options;
  // End timestamp provider is only needed when the TTFD timeout is triggered
  final EndTimestampProvider _endTimestampProvider;
  final Duration _autoFinishAfter;

  ISentrySpan? _transaction;
  ISentrySpan? _ttfdSpan;
  Completer<void> _completedTTFDTracking = Completer<void>();

  Future<void> track({
    required ISentrySpan transaction,
  }) async {
    if (transaction is! SentryTracer) {
      return;
    }
    _transaction = transaction;

    _ttfdSpan = transaction.startChild(
      SentrySpanOperations.uiTimeToFullDisplay,
      description: '${transaction.name} full display',
      startTimestamp: transaction.startTimestamp,
    );
    _ttfdSpan?.origin = SentryTraceOrigins.manualUiTimeToDisplay;
    // Wait for TTFD to finish
    await _completedTTFDTracking.future.timeout(
      _autoFinishAfter,
      onTimeout: _handleTimeout,
    );
  }

  Future<void> reportFullyDisplayed({SpanId? spanId}) async {
    final startSpanId = _transaction?.context.spanId;
    final endSpanId = spanId;

    if (startSpanId != null && endSpanId != null && startSpanId != endSpanId) {
      return;
    }
    await _complete(getUtcDateTime());
  }

  void _handleTimeout() {
    _complete(null);
  }

  Future<void> _complete(DateTime? timestamp) async {
    final ttfdSpan = _ttfdSpan;
    final endTimestamp = timestamp ?? _endTimestampProvider();

    if (ttfdSpan == null || ttfdSpan.finished || endTimestamp == null) {
      _options.logger(
        SentryLevel.warning,
        'TTFD tracker not started or already completed. Dropping TTFD measurement.',
      );
      _completedTTFDTracking.complete();
      clear();
      return;
    }

    // If a timestamp is provided, the operation was successful; otherwise, it timed out
    final status =
        timestamp != null ? SpanStatus.ok() : SpanStatus.deadlineExceeded();
    try {
      // Should only add measurements if the span is successful
      if (status == SpanStatus.ok()) {
        _setTTFDMeasurement(ttfdSpan.startTimestamp, endTimestamp);
      }
      await ttfdSpan.finish(
        status: status,
        endTimestamp: endTimestamp,
      );
    } catch (e, stackTrace) {
      _options.logger(
        SentryLevel.error,
        'Failed to finish TTFD span',
        exception: e,
        stackTrace: stackTrace,
      );
    } finally {
      _completedTTFDTracking.complete();
      clear();
    }
  }

  void _setTTFDMeasurement(DateTime startTimestamp, DateTime endTimestamp) {
    final duration = endTimestamp.difference(startTimestamp);
    final measurement = SentryMeasurement.timeToFullDisplay(duration);
    _transaction?.setMeasurement(measurement.name, measurement.value,
        unit: measurement.unit);
  }

  void clear() {
    _ttfdSpan = null;
    _transaction = null;
    _completedTTFDTracking = Completer();
  }
}

/// We need to retrieve the end time stamp in case TTFD timeout is triggered.
/// In those cases TTFD end time should match TTID end time.
/// This provider allows us to inject endTimestamps for testing as well.
@internal
typedef EndTimestampProvider = DateTime? Function();
