import 'package:meta/meta.dart';

import '../../../sentry.dart';

/// The metrics telemetry.
sealed class SentryMetric {
  final String type;

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
  }) : super(type: 'counter');
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
  }) : super(type: 'gauge');
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
  }) : super(type: 'distribution');
}
