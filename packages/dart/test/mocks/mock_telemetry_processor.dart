import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/processing/processor.dart';

class MockTelemetryProcessor implements TelemetryProcessor {
  final List<SentryLog> addedLogs = [];
  int flushCalls = 0;
  int closeCalls = 0;

  @override
  void addLog(SentryLog log) {
    addedLogs.add(log);
  }

  @override
  void flush() {
    flushCalls++;
  }
}
