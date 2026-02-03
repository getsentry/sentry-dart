import 'dart:async';

import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/processing/processor.dart';

/// Fake telemetry processor that captures telemetry data for test assertions.
///
/// Usage:
/// ```dart
/// final processor = FakeTelemetryProcessor();
/// final options = SentryOptions()
///   ..telemetryProcessor = processor;
/// ```
class FakeTelemetryProcessor implements TelemetryProcessor {
  final List<RecordingSentrySpanV2> capturedSpans = [];

  @override
  void addSpan(RecordingSentrySpanV2 span) {
    capturedSpans.add(span);
  }

  @override
  void addLog(SentryLog log) {}

  @override
  void addMetric(SentryMetric metric) {}

  @override
  FutureOr<void> flush() {}

  void clear() {
    capturedSpans.clear();
  }

  List<RecordingSentrySpanV2> getChildSpans() {
    return capturedSpans.where((s) => s.parentSpan != null).toList();
  }

  RecordingSentrySpanV2? findSpanByOperation(String operation) {
    return capturedSpans.firstWhereOrNull(
      (span) => span.attributes['sentry.op']?.value == operation,
    );
  }

  List<RecordingSentrySpanV2> findChildrenOf(RecordingSentrySpanV2 parent) {
    return capturedSpans.where((s) => s.parentSpan == parent).toList();
  }

  Future<void> waitForProcessing() async {
    // Small delay to ensure async telemetry callbacks complete.
    await Future.delayed(Duration(milliseconds: 10));
  }
}
