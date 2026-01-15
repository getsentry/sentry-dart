import 'package:meta/meta.dart';

import '../../../sentry.dart';

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

/// Base sealed class for all Sentry metrics
sealed class SentryMetric {
  final SentryMetricType type;

  DateTime timestamp;
  String name;
  num value;
  SentryId traceId;
  SpanId? spanId;
  String? unit;
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
      'type': type.value,
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

/// Counter metric - increments counts
final class SentryCounterMetric extends SentryMetric {
  SentryCounterMetric({
    required super.timestamp,
    required super.name,
    required super.value,
    required super.traceId,
    super.spanId,
    super.unit,
    super.attributes,
  }) : super(type: SentryMetricType.counter);
}

/// Gauge metric - tracks values that can go up or down
final class SentryGaugeMetric extends SentryMetric {
  SentryGaugeMetric({
    required super.timestamp,
    required super.name,
    required super.value,
    required super.traceId,
    super.spanId,
    super.unit,
    super.attributes,
  }) : super(type: SentryMetricType.gauge);
}

/// Distribution metric - tracks statistical distribution of values
final class SentryDistributionMetric extends SentryMetric {
  SentryDistributionMetric({
    required super.timestamp,
    required super.name,
    required super.value,
    required super.traceId,
    super.spanId,
    super.unit,
    super.attributes,
  }) : super(type: SentryMetricType.distribution);
}
