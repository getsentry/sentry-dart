// ignore_for_file: invalid_use_of_internal_member

import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/app_start/standalone/app_start_trace.dart';

final class TestAppStartTrace implements AppStartTrace {
  TestAppStartTrace({
    this.extendedSpan,
    this.extendedSpanV2,
    this.refuseExtension = false,
  });

  /// Stands in for a trace that turns the extension down — already extended,
  /// past its first frame, or winding down.
  final bool refuseExtension;

  DateTime? extensionStart;
  DateTime? extensionEnd;

  @override
  final ISentrySpan? extendedSpan;

  @override
  final SentrySpanV2? extendedSpanV2;

  @override
  bool tryExtend(DateTime startTimestamp) {
    if (refuseExtension) return false;
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
  Future<void> close() async {}
}
