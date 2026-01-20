import 'package:meta/meta.dart';

import '../../../sentry.dart';

/// Base class for metric data points sent to Sentry.
///
/// See [SentryCounterMetric], [SentryGaugeMetric], and [SentryDistributionMetric]
/// for concrete metric types.
abstract class SentryMetric {
  /// The metric type identifier (e.g., 'counter', 'gauge', 'distribution').
  final String type;

  /// The time when the metric was recorded.
  DateTime timestamp;

  /// The metric name, typically using dot notation (e.g., 'app.memory_usage').
  String name;

  /// The numeric value of the metric.
  num value;

  /// The trace ID from the current propagation context.
  SentryId traceId;

  /// The span ID of the active span when the metric was recorded.
  SpanId? spanId;

  /// The unit of measurement (e.g., 'millisecond', 'byte').
  ///
  /// For a list of supported units, see https://develop.sentry.dev/sdk/telemetry/attributes/#units.
  String? unit;

  /// Custom key-value pairs attached to the metric.
  Map<String, SentryAttribute> attributes;

  SentryMetric({
    required this.timestamp,
    required this.type,
    required this.name,
    required this.value,
    required this.traceId,
    this.spanId,
    this.unit,
    Map<String, SentryAttribute>? attributes,
  }) : attributes = attributes ?? {};

  @internal
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch / 1000.0,
      'type': type,
      'name': name,
      'value': value,
      'trace_id': traceId,
      if (spanId != null) 'span_id': spanId,
      if (unit != null) 'unit': unit,
      if (attributes.isNotEmpty)
        'attributes': attributes.map((k, v) => MapEntry(k, v.toJson())),
    };
  }
}

/// A metric that tracks the number of times an event occurs.
final class SentryCounterMetric extends SentryMetric {
  SentryCounterMetric({
    required super.timestamp,
    required super.name,
    required super.value,
    required super.traceId,
    super.spanId,
    super.unit,
    super.attributes,
  }) : super(type: 'counter');
}

/// A metric that tracks a value which can increase or decrease over time.
final class SentryGaugeMetric extends SentryMetric {
  SentryGaugeMetric({
    required super.timestamp,
    required super.name,
    required super.value,
    required super.traceId,
    super.spanId,
    super.unit,
    super.attributes,
  }) : super(type: 'gauge');
}

/// A metric that tracks the statistical distribution of a set of values.
final class SentryDistributionMetric extends SentryMetric {
  SentryDistributionMetric({
    required super.timestamp,
    required super.name,
    required super.value,
    required super.traceId,
    super.spanId,
    super.unit,
    super.attributes,
  }) : super(type: 'distribution');
}
