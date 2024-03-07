// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:meta/meta.dart';

// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';

import '../../sentry_flutter.dart';
import 'time_to_initial_display_tracker.dart';

/// We need to retrieve the end time stamp in case TTFD timeout is triggered.
/// In those cases TTFD end time should match TTID end time.
/// This provider allows us to inject endTimestamps for testing as well.
@internal
abstract class EndTimestampProvider {
  DateTime? get endTimestamp;
}

@internal
class TTIDEndTimestampProvider implements EndTimestampProvider {
  @override
  DateTime? get endTimestamp => TimeToInitialDisplayTracker().endTimestamp;
}

@internal
class TimeToFullDisplayTracker {
  static final TimeToFullDisplayTracker _instance =
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

  TimeToFullDisplayTracker._();

  DateTime? _startTimestamp;
  ISentrySpan? _ttfdSpan;
  Timer? _ttfdTimer;
  ISentrySpan? _transaction;
  Duration _autoFinishAfter = const Duration(seconds: 30);
  EndTimestampProvider _endTimestampProvider = TTIDEndTimestampProvider();
  Completer<void> _completedTTFDTracking = Completer<void>();

  Future<void> track(ISentrySpan transaction, DateTime startTimestamp) async {
    _startTimestamp = startTimestamp;
    _transaction = transaction as SentryTracer;
    _ttfdSpan = transaction.startChild(SentrySpanOperations.uiTimeToFullDisplay,
        description: '${transaction.name} full display',
        startTimestamp: startTimestamp);
    _ttfdSpan?.origin = SentryTraceOrigins.manualUiTimeToDisplay;
    _ttfdTimer = Timer(_autoFinishAfter, handleTimeToFullDisplayTimeout);
    await _completedTTFDTracking.future;

    clear();
  }

  void handleTimeToFullDisplayTimeout() {
    final ttfdSpan = _ttfdSpan;
    final startTimestamp = _startTimestamp;
    final endTimestamp = _endTimestampProvider.endTimestamp;

    if (ttfdSpan == null ||
        ttfdSpan.finished == true ||
        startTimestamp == null ||
        endTimestamp == null) {
      _completedTTFDTracking.complete();
      return;
    }

    _setTTFDMeasurement(startTimestamp, endTimestamp);
    ttfdSpan.finish(
        status: SpanStatus.deadlineExceeded(), endTimestamp: endTimestamp);

    _completedTTFDTracking.complete();
  }

  Future<void> reportFullyDisplayed() async {
    _ttfdTimer?.cancel();
    final endTimestamp = DateTime.now();
    final startTimestamp = _startTimestamp;
    final ttfdSpan = _ttfdSpan;

    if (ttfdSpan?.finished == true || startTimestamp == null) {
      _completedTTFDTracking.complete();
      return;
    }

    _setTTFDMeasurement(startTimestamp, endTimestamp);
    await ttfdSpan?.finish(status: SpanStatus.ok(), endTimestamp: endTimestamp);

    _completedTTFDTracking.complete();
  }

  void _setTTFDMeasurement(DateTime startTimestamp, DateTime endTimestamp) {
    final duration = endTimestamp.difference(startTimestamp);
    final measurement = SentryMeasurement.timeToFullDisplay(duration);
    _transaction?.setMeasurement(measurement.name, measurement.value,
        unit: measurement.unit);
  }

  void clear() {
    _startTimestamp = null;
    _ttfdSpan = null;
    _ttfdTimer = null;
    _transaction = null;
    _completedTTFDTracking = Completer<void>();
  }
}
