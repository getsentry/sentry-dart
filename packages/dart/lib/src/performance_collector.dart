import '../sentry.dart';

abstract class PerformanceCollector {}

/// Used for collecting continuous data about vitals (slow, frozen frames, etc.)
/// during a transaction/span.
abstract class PerformanceContinuousCollector extends PerformanceCollector {
  Future<void> onSpanStarted(ISentrySpan span);

  Future<void> onSpanFinished(ISentrySpan span, DateTime endTimestamp);

  void clear();
}
