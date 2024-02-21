import 'dart:async';

import '../../sentry_flutter.dart';
import '../sentry_flutter_measurement.dart';

class TimeToFullDisplayTracker {
  static final TimeToFullDisplayTracker _singleton =
      TimeToFullDisplayTracker._internal();

  factory TimeToFullDisplayTracker() {
    return _singleton;
  }

  TimeToFullDisplayTracker._internal();

  DateTime? _startTimestamp;
  DateTime? _ttfdEndTimestamp;
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
    await ttfdSpan.finish(endTimestamp: endTimestamp);
  }

  void initializeTTFD(
      ISentrySpan transaction, DateTime startTimestamp, String routeName) {
    _startTimestamp = startTimestamp;
    _transaction = transaction;
    _ttfdSpan = transaction.startChild(
        SentrySpanOperations.uiTimeToFullDisplay,
        description: '$routeName full display',
        startTimestamp: startTimestamp);
    _ttfdTimer =
        Timer(ttfdAutoFinishAfter, handleTimeToFullDisplayTimeout);
  }

  void setTTFDEndTimestamp(DateTime ttfdEndTimestamp) {
    _ttfdEndTimestamp = ttfdEndTimestamp;
  }

  void handleTimeToFullDisplayTimeout() {
    final ttfdSpan = _ttfdSpan;
    final endTimestamp = _ttfdEndTimestamp ?? DateTime.now();
    final startTimestamp = _startTimestamp;
    if (ttfdSpan == null ||
        ttfdSpan.finished == true ||
        startTimestamp == null) {
      return;
    }

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
