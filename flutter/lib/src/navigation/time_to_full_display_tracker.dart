import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../sentry_flutter_measurement.dart';
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

  void startTracking(
      ISentrySpan transaction, DateTime startTimestamp, String routeName) {
    _startTimestamp = startTimestamp;
    _transaction = transaction;
    _ttfdSpan = transaction.startChild(SentrySpanOperations.uiTimeToFullDisplay,
        description: '$routeName full display', startTimestamp: startTimestamp);
    _ttfdSpan?.origin = SentryTraceOrigins.manualUiTimeToDisplay;
    _ttfdTimer = Timer(_autoFinishAfter, handleTimeToFullDisplayTimeout);
  }

  void handleTimeToFullDisplayTimeout() {
    final ttfdSpan = _ttfdSpan;
    final startTimestamp = _startTimestamp;
    if (ttfdSpan == null ||
        ttfdSpan.finished == true ||
        startTimestamp == null) {
      return;
    }

    // If for some reason we can't get the ttid end timestamp
    // we'll use the start timestamp + autoFinishAfter as a fallback
    final endTimestamp = _endTimestampProvider.endTimestamp ??
        startTimestamp.add(_autoFinishAfter);

    _setTTFDMeasurement(startTimestamp, endTimestamp);
    ttfdSpan.finish(
        status: SpanStatus.deadlineExceeded(), endTimestamp: endTimestamp);

    clearState();
  }

  Future<void> reportFullyDisplayed() async {
    _ttfdTimer?.cancel();
    final endTimestamp = DateTime.now();
    final startTimestamp = _startTimestamp;
    final ttfdSpan = _ttfdSpan;

    if (ttfdSpan == null ||
        ttfdSpan.finished == true ||
        startTimestamp == null) {
      return;
    }

    _setTTFDMeasurement(startTimestamp, endTimestamp);
    await ttfdSpan.finish(endTimestamp: endTimestamp);

    clearState();
  }

  void _setTTFDMeasurement(DateTime startTimestamp, DateTime endTimestamp) {
    final duration = endTimestamp.difference(startTimestamp);
    final measurement = SentryFlutterMeasurement.timeToFullDisplay(duration);
    _transaction?.setMeasurement(measurement.name, measurement.value,
        unit: measurement.unit);
  }

  void clearState() {
    _startTimestamp = null;
    _ttfdSpan = null;
    _ttfdTimer = null;
    _transaction = null;
  }
}
