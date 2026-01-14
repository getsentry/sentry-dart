import '../sentry.dart';
import 'telemetry/span/sentry_span_v2.dart';

abstract class PerformanceCollector {}

/// Used for collecting continuous data about vitals (slow, frozen frames, etc.)
/// during a transaction/span.
abstract class PerformanceContinuousCollector extends PerformanceCollector {
  Future<void> onSpanStarted(ISentrySpan span);

  Future<void> onSpanFinished(ISentrySpan span, DateTime endTimestamp);

  void clear();
}

/// Used for collecting continuous data about vitals (slow, frozen frames, etc.)
/// during a transaction/span.
abstract class PerformanceContinuousCollectorV2 extends PerformanceCollector {
  Future<void> onSpanStarted(SentrySpanV2 span);

  Future<void> onSpanFinished(SentrySpanV2 span, DateTime endTimestamp);

  void clear();
}
