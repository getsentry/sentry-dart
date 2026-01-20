import '../../../sentry.dart';

/// Interface for emitting custom metrics to Sentry.
///
/// Access via [Sentry.metrics].
abstract interface class SentryMetrics {
  /// Increments a counter metric by the given [value].
  ///
  /// Use counters to track the number of times an event occurs.
  void count(String name, int value,
      {Map<String, SentryAttribute>? attributes, Scope? scope});

  /// Records a value in a distribution metric.
  ///
  /// Use distributions to track the statistical distribution of values,
  /// such as response times or file sizes.
  ///
  /// See [SentryMetricUnit] for predefined unit constants.
  void distribution(String name, num value,
      {String? unit, Map<String, SentryAttribute>? attributes, Scope? scope});

  /// Sets the current value of a gauge metric.
  ///
  /// Use gauges to track values that can increase or decrease over time,
  /// such as memory usage or queue depth.
  ///
  /// See [SentryMetricUnit] for predefined unit constants.
  void gauge(String name, num value,
      {String? unit, Map<String, SentryAttribute>? attributes, Scope? scope});
}
