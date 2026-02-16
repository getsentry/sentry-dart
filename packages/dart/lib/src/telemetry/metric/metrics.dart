import '../../../sentry.dart';

/// Interface for emitting custom metrics to Sentry.
///
/// Access via [Sentry.metrics].
abstract interface class SentryMetrics {
  /// Increments a cumulative counter by [value].
  ///
  /// Use counters for values that only increase, like request counts or error
  /// totals. The [name] identifies the metric (e.g., `'api.requests'`).
  /// Optionally attach [attributes] to add dimensions for filtering.
  ///
  /// ```dart
  /// Sentry.metrics.count(
  ///   'api.requests',
  ///   1,
  ///   attributes: {
  ///     'endpoint': SentryAttribute.string('/api/users'),
  ///     'method': SentryAttribute.string('POST'),
  ///   },
  /// );
  /// ```
  void count(
    String name,
    int value, {
    Map<String, SentryAttribute>? attributes,
  });

  /// Records a point-in-time [value] that can increase or decrease.
  ///
  /// Use gauges for values that fluctuate, like memory usage, queue depth, or
  /// active connections. The [name] identifies the metric. Specify [unit] to
  /// describe the measurement—  [SentryMetricUnit] provides officially supported
  /// units (e.g., [SentryMetricUnit.byte]), but custom strings are also
  /// accepted. Optionally attach [attributes] to add dimensions for filtering.
  ///
  /// ```dart
  /// Sentry.metrics.gauge(
  ///   'memory.heap_used',
  ///   1,
  ///   unit: SentryMetricUnit.megabyte,
  ///   attributes: {
  ///     'process': SentryAttribute.string('main'),
  ///   },
  /// );
  /// ```
  void gauge(
    String name,
    num value, {
    String? unit,
    Map<String, SentryAttribute>? attributes,
  });

  /// Records a [value] for statistical distribution analysis.
  ///
  /// Use distributions to track values where you need percentiles, averages,
  /// and histograms—like response times or payload sizes. The [name] identifies
  /// the metric. Specify [unit] to describe the measurement — [SentryMetricUnit]
  /// provides officially supported units (e.g., [SentryMetricUnit.millisecond]),
  /// but custom strings are also accepted. Optionally attach [attributes] to
  /// add dimensions for filtering.
  ///
  /// ```dart
  /// Sentry.metrics.distribution(
  ///   'http.request.duration',
  ///   245.3,
  ///   unit: SentryMetricUnit.millisecond,
  ///   attributes: {
  ///     'endpoint': SentryAttribute.string('/api/users'),
  ///     'status_code': SentryAttribute.int(200),
  ///   },
  /// );
  /// ```
  void distribution(
    String name,
    num value, {
    String? unit,
    Map<String, SentryAttribute>? attributes,
  });
}
