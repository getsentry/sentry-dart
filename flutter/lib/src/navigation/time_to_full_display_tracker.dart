import 'dart:async';

import '../../sentry_flutter.dart';
import '../sentry_flutter_measurement.dart';
import 'time_to_initial_display_tracker.dart';

class TimeToFullDisplayTracker {
  static final TimeToFullDisplayTracker _singleton =
      TimeToFullDisplayTracker._internal();

  factory TimeToFullDisplayTracker() {
    return _singleton;
  }

  TimeToFullDisplayTracker._internal();

  DateTime? _startTimestamp;
  ISentrySpan? _ttfdSpan;
  Timer? _ttfdTimer;
  ISentrySpan? _transaction;
  Duration ttfdAutoFinishAfter = const Duration(seconds: 30);

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
    return ttfdSpan.finish(endTimestamp: endTimestamp);
  }

  void startTracking(
      ISentrySpan transaction, DateTime startTimestamp, String routeName) {
    _startTimestamp = startTimestamp;
    _transaction = transaction;
    _ttfdSpan = transaction.startChild(SentrySpanOperations.uiTimeToFullDisplay,
        description: '$routeName full display', startTimestamp: startTimestamp);
    _ttfdSpan?.origin = SentryTraceOrigins.manualUiTimeToDisplay;
    _ttfdTimer = Timer(ttfdAutoFinishAfter, handleTimeToFullDisplayTimeout);
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
    // we'll use the start timestamp + autoFinishTime as a fallback
    final endTimestamp = TimeToInitialDisplayTracker().endTimestamp ??
        startTimestamp.add(ttfdAutoFinishAfter);

    _setTTFDMeasurement(startTimestamp, endTimestamp);
    ttfdSpan.finish(
        status: SpanStatus.deadlineExceeded(), endTimestamp: endTimestamp);
  }

  void _setTTFDMeasurement(DateTime startTimestamp, DateTime endTimestamp) {
    final duration = endTimestamp.difference(startTimestamp);
    final measurement = SentryFlutterMeasurement.timeToFullDisplay(duration);
    _transaction?.setMeasurement(measurement.name, measurement.value,
        unit: measurement.unit);
  }
}
