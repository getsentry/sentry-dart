import 'dart:async';

import 'package:sentry/src/protocol/sentry_log.dart';
import 'package:sentry/src/sentry_log_batcher.dart';

class MockLogBatcher implements SentryLogBatcher {
  final addLogCalls = <SentryLog>[];
  final flushCalls = <void>[];

  @override
  FutureOr<void> addLog(SentryLog log) {
    addLogCalls.add(log);
  }

  @override
  FutureOr<void> flush() async {
    flushCalls.add(null);
  }
}
