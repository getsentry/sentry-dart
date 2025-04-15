// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:meta/meta.dart';
// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';

import '../../sentry_flutter.dart';
import 'time_to_initial_display_tracker.dart';

@internal
class TimeToFullDisplayTracker {
  static final TimeToFullDisplayTracker _instance =
      TimeToFullDisplayTracker._();

  TimeToFullDisplayTracker._();

  factory TimeToFullDisplayTracker(
      {EndTimestampProvider? endTimestampProvider, Duration? autoFinishAfter}) {
    if (autoFinishAfter != null) {
      _instance._autoFinishAfter = autoFinishAfter;
    }
    if (endTimestampProvider != null) {
      _instance._endTimestampProvider = endTimestampProvider;
    }
    return _instance;
  }

  DateTime? _startTimestamp;
  ISentrySpan? _ttfdSpan;
  String? _routeName;
  ISentrySpan? _transaction;
  Duration _autoFinishAfter = const Duration(seconds: 30);
  final options = Sentry.currentHub.options;

  // End timestamp provider is only needed when the TTFD timeout is triggered
  EndTimestampProvider _endTimestampProvider = ttidEndTimestampProvider;
  Completer<void> _completedTTFDTracking = Completer<void>();

  Future<void> track({
    required ISentrySpan transaction,
    required DateTime startTimestamp,
    required String routeName,
  }) async {
    if (transaction is! SentryTracer) {
      return;
    }
    _startTimestamp = startTimestamp;
    _routeName = routeName;

    _transaction = transaction;
    _ttfdSpan = transaction.startChild(
      SentrySpanOperations.uiTimeToFullDisplay,
      description: '${transaction.name} full display',
      startTimestamp: startTimestamp,
    );
    _ttfdSpan?.origin = SentryTraceOrigins.manualUiTimeToDisplay;
    // Wait for TTFD to finish
    await _completedTTFDTracking.future.timeout(
      _autoFinishAfter,
      onTimeout: _handleTimeout,
    );
  }

  Future<void> reportFullyDisplayed({String? routeName}) async {
    final startRouteName = _routeName;
    final endRouteName = routeName;

    if (startRouteName != null &&
        endRouteName != null &&
        startRouteName != endRouteName) {
      options.logger(
        SentryLevel.warning,
        'TTFD tracker for route "$startRouteName" does not match requested route "$endRouteName"',
      );
      return;
    }
    await _complete(getUtcDateTime());
  }

  void _handleTimeout() {
    _complete(null);
  }

  Future<void> _complete(DateTime? timestamp) async {
    final ttfdSpan = _ttfdSpan;
    final startTimestamp = _startTimestamp;
    final endTimestamp = timestamp ?? _endTimestampProvider();

    if (ttfdSpan == null ||
        ttfdSpan.finished ||
        startTimestamp == null ||
        endTimestamp == null) {
      options.logger(
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
        _setTTFDMeasurement(startTimestamp, endTimestamp);
      }
      await ttfdSpan.finish(
        status: status,
        endTimestamp: endTimestamp,
      );
    } catch (e, stackTrace) {
      options.logger(
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
    _startTimestamp = null;
    _routeName = null;
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

@internal
EndTimestampProvider ttidEndTimestampProvider =
    () => TimeToInitialDisplayTracker().endTimestamp;

// Screen A, starts async task like HTTP fetching and finishes TTFD after 5 seconds
