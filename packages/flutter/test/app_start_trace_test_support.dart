// ignore_for_file: invalid_use_of_internal_member

import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/app_start/standalone/app_start_trace.dart';

final class TestAppStartTrace implements AppStartTrace {
  TestAppStartTrace({
    ISentrySpan? extendedSpan,
    SentrySpanV2? extendedSpanV2,
  })  : extendedSpan = extendedSpan ?? NoOpSentrySpan(),
        extendedSpanV2 = extendedSpanV2 ?? const NoOpSentrySpanV2();

  DateTime? extensionStart;
  DateTime? extensionEnd;

  @override
  final ISentrySpan extendedSpan;

  @override
  final SentrySpanV2 extendedSpanV2;

  @override
  bool tryExtend(DateTime startTimestamp) {
    extensionStart = startTimestamp;
    return true;
  }

  @override
  Future<void> finishExtended(DateTime endTimestamp) async {
    extensionEnd = endTimestamp;
  }

  @override
  void recordFirstFrame(DateTime endTimestamp) {}

  @override
  void finish(DateTime endTimestamp) {}

  @override
  void close() {}
}
