import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/processing/processor.dart';

class MockTelemetryProcessor implements TelemetryProcessor {
  final List<RecordingSentrySpanV2> addedSpans = [];
  final List<SentryLog> addedLogs = [];
  final List<SentryMetric> addedMetrics = [];
  int flushCalls = 0;
  int closeCalls = 0;

  /// When set, [addLog] throws this error instead of recording the log.
  Object? addLogError;

  @override
  void addSpan(RecordingSentrySpanV2 span) {
    addedSpans.add(span);
  }

  @override
  void addLog(SentryLog log) {
    final error = addLogError;
    if (error != null) {
      throw error;
    }
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
