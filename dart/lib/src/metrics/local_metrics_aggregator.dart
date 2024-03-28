import 'dart:core';
import 'package:meta/meta.dart';
import '../protocol/metric_summary.dart';
import 'metric.dart';

@internal
class LocalMetricsAggregator {
  // format: <export key, <metric key, gauge>>
  final Map<String, Map<String, GaugeMetric>> _buckets = {};

  void add(final Metric metric, final num value) {
    final bucket =
        _buckets.putIfAbsent(metric.getSpanAggregationKey(), () => {});

    bucket.update(metric.getCompositeKey(), (m) => m..add(value),
        ifAbsent: () => Metric.fromType(
            type: MetricType.gauge,
            key: metric.key,
            value: value,
            unit: metric.unit,
            tags: metric.tags) as GaugeMetric);
  }

  Map<String, List<MetricSummary>> getSummaries() {
    final Map<String, List<MetricSummary>> summaries = {};
    for (final entry in _buckets.entries) {
      final String exportKey = entry.key;

      final metricSummaries = entry.value.values
          .map((gauge) => MetricSummary.fromGauge(gauge))
          .toList();

      summaries[exportKey] = metricSummaries;
    }
    return summaries;
  }
}
