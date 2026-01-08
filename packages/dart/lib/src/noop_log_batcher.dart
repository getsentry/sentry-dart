import 'dart:async';

import 'sentry_log_batcher.dart';
import 'protocol/sentry_log.dart';

class NoopLogBatcher implements SentryLogBatcher {
  @override
  FutureOr<void> addLog(SentryLog log) {}

  @override
  FutureOr<void> flush() {}
}
