/// The type of metric being recorded
enum SentryMetricType {
  /// A metric that increments counts
  counter('counter'),

  /// A metric that tracks a value that can go up or down
  gauge('gauge'),

  /// A metric that tracks statistical distribution of values
  distribution('distribution');

  final String value;
  const SentryMetricType(this.value);
}
