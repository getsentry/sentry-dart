// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:meta/meta.dart';
// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';

import '../../sentry_flutter.dart';
import '../frame_callback_handler.dart';

@internal
class TimeToInitialDisplayTracker {
  TimeToInitialDisplayTracker({
    FrameCallbackHandler? frameCallbackHandler,
  }) : _frameCallbackHandler =
            frameCallbackHandler ?? DefaultFrameCallbackHandler();

  final FrameCallbackHandler _frameCallbackHandler;

  Completer<DateTime?>? _trackingCompleter;

  Future<ISentrySpan?> track({
    required SentryTracer transaction,
    DateTime? endTimestamp,
  }) async {
    final ttidSpan = transaction.startChild(
      SentrySpanOperations.uiTimeToInitialDisplay,
      description: '${transaction.name} initial display',
      startTimestamp: transaction.startTimestamp,
    );
    ttidSpan.origin = SentryTraceOrigins.autoUiTimeToDisplay;

    final determinedEndTimestamp = await _determineEndTime(endTimestamp);
    final fallbackEndTimestamp = getUtcDateTime();
    final _endTimestamp = determinedEndTimestamp ?? fallbackEndTimestamp;

    // If a timestamp is provided, the operation was successful; otherwise, it timed out
    final status = determinedEndTimestamp != null
        ? SpanStatus.ok()
        : SpanStatus.deadlineExceeded();

    // Should only add measurements if the span is successful
    if (status == SpanStatus.ok()) {
      final ttidMeasurement = SentryMeasurement.timeToInitialDisplay(
        _endTimestamp.difference(transaction.startTimestamp),
      );
      transaction.setMeasurement(
        ttidMeasurement.name,
        ttidMeasurement.value,
        unit: ttidMeasurement.unit,
      );
    }

    await ttidSpan.finish(
      status: status,
      endTimestamp: _endTimestamp,
    );

    return ttidSpan;
  }

  FutureOr<DateTime?> _determineEndTime(DateTime? endTimestamp) {
    if (endTimestamp != null) {
      return endTimestamp;
    }
    _trackingCompleter = Completer<DateTime?>();
    _frameCallbackHandler.addPostFrameCallback((_) {
      _reportInitialDisplayed();
    });
    return _trackingCompleter?.future.timeout(
      Duration(seconds: 5),
      onTimeout: () => Future.value(null),
    );
  }

  Future<void> _reportInitialDisplayed() async {
    if (_trackingCompleter != null && !_trackingCompleter!.isCompleted) {
      _trackingCompleter?.complete(DateTime.now());
    }
  }

  void clear() {
    _trackingCompleter = null;
  }
}
