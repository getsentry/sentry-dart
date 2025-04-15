// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:meta/meta.dart';
// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';
import '../../sentry_flutter.dart';

@internal
class TimeToFullDisplayTracker {
  TimeToFullDisplayTracker({
    required SentryOptions options,
    required EndTimestampProvider endTimestampProvider,
    Duration autoFinishAfter = const Duration(seconds: 30),
  }) {
    _options = options;
    _endTimestampProvider = endTimestampProvider;
    _autoFinishAfter = autoFinishAfter;
  }

  ISentrySpan? _transaction;
  String? _routeName;

  ISentrySpan? _ttfdSpan;

  late final SentryOptions _options;
  // End timestamp provider is only needed when the TTFD timeout is triggered
  late final EndTimestampProvider _endTimestampProvider;
  late final Duration _autoFinishAfter;
  Completer<void> _completedTTFDTracking = Completer<void>();

  Future<void> track({
    required ISentrySpan transaction,
    required String routeName,
  }) async {
    if (transaction is! SentryTracer) {
      return;
    }
    _transaction = transaction;
    _routeName = routeName;

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

  Future<void> reportFullyDisplayed({String? routeName}) async {
    final startRouteName = _routeName;
    final endRouteName = routeName;

    if (startRouteName != null &&
        endRouteName != null &&
        startRouteName != endRouteName) {
      _options.logger(
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
