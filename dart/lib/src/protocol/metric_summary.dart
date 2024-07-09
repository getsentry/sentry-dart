import 'package:meta/meta.dart';

import '../metrics/metric.dart';
import 'unknown.dart';

class MetricSummary {
  final num min;
  final num max;
  final num sum;
  final int count;
  final Map<String, String>? tags;

  @internal
  final Map<String, dynamic>? unknown;

  MetricSummary.fromGauge(GaugeMetric gauge, {this.unknown})
      : min = gauge.minimum,
        max = gauge.maximum,
        sum = gauge.sum,
        count = gauge.count,
        tags = gauge.tags;

  const MetricSummary(
      {required this.min,
      required this.max,
      required this.sum,
      required this.count,
      required this.tags,
      this.unknown});

  /// Deserializes a [MetricSummary] from JSON [Map].
  factory MetricSummary.fromJson(Map<String, dynamic> data) => MetricSummary(
        min: data['min'],
        max: data['max'],
        count: data['count'],
        sum: data['sum'],
        tags: data['tags']?.cast<String, String>(),
        unknown: unknownFrom(data, {
          'min',
          'max',
          'count',
          'sum',
          'tags',
        }),
      );

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'min': min,
      'max': max,
      'count': count,
      'sum': sum,
      if (tags?.isNotEmpty ?? false) 'tags': tags,
    };
    json.addAll(unknown ?? {});
    return json;
  }
}
