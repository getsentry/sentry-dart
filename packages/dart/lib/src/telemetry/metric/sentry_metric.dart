import 'package:meta/meta.dart';

import '../../../sentry.dart';
import 'metric_type.dart';

/// Base sealed class for all Sentry metrics
sealed class SentryMetric {
  final DateTime timestamp;
  final SentryMetricType type;
  final String name;
  final num value;
  final SentryId traceId;
  final SpanId? spanId;
  final String? unit;
  final Map<String, SentryAttribute> attributes;

  const SentryMetric({
    required this.timestamp,
    required this.type,
    required this.name,
    required this.value,
    required this.traceId,
    this.spanId,
    this.unit,
    this.attributes = const {},
  });

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

/// Counter metric - increments counts (only increases)
final class SentryCounterMetric extends SentryMetric {
  const SentryCounterMetric({
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
  const SentryGaugeMetric({
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
  const SentryDistributionMetric({
    required super.timestamp,
    required super.name,
    required super.value,
    required super.traceId,
    super.spanId,
    super.unit,
    super.attributes,
  }) : super(type: SentryMetricType.distribution);
}
