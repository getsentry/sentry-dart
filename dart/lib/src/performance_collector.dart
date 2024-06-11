import '../sentry.dart';

abstract class PerformanceCollector {}

/// Used for collecting continuous data about vitals (slow, frozen frames, etc.)
/// during a transaction/span.
abstract class PerformanceContinuousCollector extends PerformanceCollector {
  void onSpanStarted(ISentrySpan span);

  void onSpanFinished(ISentrySpan span);

  void clear();
}
