import '../sentry.dart';

abstract class PerformanceCollector {}

/// Used for collecting continuous data about vitals (slow, frozen frames, etc.)
/// during a transaction/span.
///
/// Deprecated: This interface is being replaced by collectors that work with
/// [InstrumentationSpan] for unified span handling.
@Deprecated('Use collectors that work with InstrumentationSpan instead')
abstract class PerformanceContinuousCollector extends PerformanceCollector {
  Future<void> onSpanStarted(ISentrySpan span);

  Future<void> onSpanFinished(ISentrySpan span, DateTime endTimestamp);

  void clear();
}

/// Used for collecting continuous data about vitals (slow, frozen frames, etc.)
/// during a span (v2 API).
///
/// Deprecated: This interface is being replaced by collectors that work with
/// [InstrumentationSpan] for unified span handling.
@Deprecated('Use collectors that work with InstrumentationSpan instead')
abstract class PerformanceContinuousCollectorV2 extends PerformanceCollector {
  Future<void> onSpanStarted(SentrySpanV2 span);

  Future<void> onSpanFinished(SentrySpanV2 span, DateTime endTimestamp);

  void clear();
}
