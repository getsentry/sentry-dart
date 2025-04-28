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
  DateTime? _endTimestamp;

  /// This endTimestamp is needed in the [TimeToFullDisplayTracker] class
  @internal
  DateTime? get endTimestamp => _endTimestamp;

  Future<void> track({
    required SentryTracer transaction,
    DateTime? endTimestamp,
    String? origin,
  }) async {
    final _endTimestamp = await _determineEndTime(endTimestamp);
    if (_endTimestamp == null) return;

    final ttidSpan = transaction.startChild(
      SentrySpanOperations.uiTimeToInitialDisplay,
      description: '${transaction.name} initial display',
      startTimestamp: transaction.startTimestamp,
    );
    ttidSpan.origin = origin ?? SentryTraceOrigins.autoUiTimeToDisplay;

    final ttidMeasurement = SentryMeasurement.timeToInitialDisplay(
      _endTimestamp.difference(transaction.startTimestamp),
    );
    transaction.setMeasurement(
      ttidMeasurement.name,
      ttidMeasurement.value,
      unit: ttidMeasurement.unit,
    );

    await ttidSpan.finish(endTimestamp: _endTimestamp);
  }

  FutureOr<DateTime?> _determineEndTime(DateTime? endTimestamp) {
    if (endTimestamp != null) {
      // Store the end timestamp for potential use by TTFD tracking
      _endTimestamp = endTimestamp;
      return endTimestamp;
    }
    _trackingCompleter = Completer<DateTime?>();
    _frameCallbackHandler.addPostFrameCallback((_) {
      if (_trackingCompleter != null && !_trackingCompleter!.isCompleted) {
        _endTimestamp = DateTime.now();
        _trackingCompleter?.complete(_endTimestamp);
      }
    });
    return _trackingCompleter?.future.timeout(
      Duration(seconds: 5),
      onTimeout: () => Future.value(null),
    );
  }

  void clear() {
    _trackingCompleter = null;
    // We can't clear the ttid end time stamp here, because it might be needed
    // in the [TimeToFullDisplayTracker] class
  }
}
