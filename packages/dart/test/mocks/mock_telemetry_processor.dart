import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/processing/processor.dart';
import 'package:sentry/src/telemetry/span/sentry_span_v2.dart';

class MockTelemetryProcessor implements TelemetryProcessor {
  final List<RecordingSentrySpanV2> addedSpans = [];
  final List<SentryLog> addedLogs = [];
  int flushCalls = 0;
  int closeCalls = 0;

  @override
  void addSpan(RecordingSentrySpanV2 span) {
    addedSpans.add(span);
  }

  @override
  void addLog(SentryLog log) {
    addedLogs.add(log);
  }

  @override
  void flush() {
    flushCalls++;
  }

  @override
  void close() {
    closeCalls++;
  }
}

