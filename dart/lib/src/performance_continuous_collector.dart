import '../sentry.dart';

/// Used for collecting continuous data about vitals (slow, frozen frames, etc.)
/// during a transaction/span.
abstract class PerformanceContinuousCollector {
  void onSpanStarted(ISentrySpan span);

  void onSpanFinished(ISentrySpan span);

  void clear();
}
