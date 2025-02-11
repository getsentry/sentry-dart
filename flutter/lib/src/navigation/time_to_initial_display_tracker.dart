// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:meta/meta.dart';
// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';

import '../../sentry_flutter.dart';
import '../frame_callback_handler.dart';

@internal
class TimeToInitialDisplayTracker {
  static final TimeToInitialDisplayTracker _instance =
      TimeToInitialDisplayTracker._();

  factory TimeToInitialDisplayTracker(
      {FrameCallbackHandler? frameCallbackHandler}) {
    if (frameCallbackHandler != null) {
      _instance._frameCallbackHandler = frameCallbackHandler;
    }
    return _instance;
  }

  TimeToInitialDisplayTracker._();

  FrameCallbackHandler _frameCallbackHandler = DefaultFrameCallbackHandler();
  Completer<DateTime?>? _trackingCompleter;
  DateTime? _endTimestamp;

  final Duration _determineEndtimeTimeout = Duration(seconds: 5);

  /// This endTimestamp is needed in the [TimeToFullDisplayTracker] class
  @internal
  DateTime? get endTimestamp => _endTimestamp;

  Future<void> track({
    required ISentrySpan transaction,
    required DateTime startTimestamp,
    DateTime? endTimestamp,
    String? origin,
  }) async {
    if (endTimestamp != null) {
      // Store the end timestamp for potential use by TTFD tracking
      this._endTimestamp = endTimestamp;
    }

    final _endTimestamp = endTimestamp ?? await determineEndTime();
    if (_endTimestamp == null) return;

    if (transaction is! SentryTracer) {
      return;
    }

    final ttidSpan = transaction.startChild(
      SentrySpanOperations.uiTimeToInitialDisplay,
      description: '${transaction.name} initial display',
      startTimestamp: startTimestamp,
    );

    ttidSpan.origin = origin ?? SentryTraceOrigins.autoUiTimeToDisplay;

    final duration = Duration(
        milliseconds: _endTimestamp.difference(startTimestamp).inMilliseconds);
    final ttidMeasurement = SentryMeasurement.timeToInitialDisplay(duration);

    transaction.setMeasurement(
      ttidMeasurement.name,
      ttidMeasurement.value,
      unit: ttidMeasurement.unit,
    );
    await ttidSpan.finish(endTimestamp: _endTimestamp);
  }

  Future<DateTime?>? determineEndTime() {
    _trackingCompleter = Completer<DateTime?>();
    final future = _trackingCompleter?.future.timeout(
      _determineEndtimeTimeout,
      onTimeout: () {
        return Future.value(null);
      },
    );

    _frameCallbackHandler.addPostFrameCallback((_) {
      completeTracking();
    });

    return future;
  }

  void completeTracking() {
    final timestamp = DateTime.now();

    if (_trackingCompleter != null && !_trackingCompleter!.isCompleted) {
      _endTimestamp = timestamp;
      _trackingCompleter?.complete(timestamp);
    }
  }

  void clear() {
    _trackingCompleter = null;
    // We can't clear the ttid end time stamp here, because it might be needed
    // in the [TimeToFullDisplayTracker] class
  }

  @visibleForTesting
  void clearForTest() {
    clear();
    _endTimestamp = null;
  }
}
