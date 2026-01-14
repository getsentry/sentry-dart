import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/metric/metric.dart';
import 'package:sentry/src/telemetry/processing/processor.dart';

class MockTelemetryProcessor implements TelemetryProcessor {
  final List<SentryLog> addedLogs = [];
  final List<SentryMetric> addedMetrics = [];
  int flushCalls = 0;
  int closeCalls = 0;

  @override
  void addLog(SentryLog log) {
    addedLogs.add(log);
  }

  @override
  void addMetric(SentryMetric metric) {
    addedMetrics.add(metric);
  }

  @override
  void flush() {
    flushCalls++;
  }
}
