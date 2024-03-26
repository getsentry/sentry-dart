import 'package:sentry/src/metrics/metric.dart';
import 'package:sentry/src/metrics/metrics_api.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import '../mocks/mock_hub.dart';

void main() {
  group('api', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('counter', () async {
      MetricsApi api = fixture.getSut();
      api.increment('key');
      api.increment('key', value: 2.4);

      Iterable<Metric> sentMetrics =
          fixture.mockHub.metricsAggregator!.buckets.values.first.values;
      expect(sentMetrics.first.type, MetricType.counter);
      expect((sentMetrics.first as CounterMetric).value, 3.4);
    });

    test('gauge', () async {
      MetricsApi api = fixture.getSut();
      api.gauge('key', value: 1.5);
      api.gauge('key', value: 2.4);

      Iterable<Metric> sentMetrics =
          fixture.mockHub.metricsAggregator!.buckets.values.first.values;
      expect(sentMetrics.first.type, MetricType.gauge);
      expect((sentMetrics.first as GaugeMetric).minimum, 1.5);
      expect((sentMetrics.first as GaugeMetric).maximum, 2.4);
      expect((sentMetrics.first as GaugeMetric).last, 2.4);
      expect((sentMetrics.first as GaugeMetric).sum, 3.9);
      expect((sentMetrics.first as GaugeMetric).count, 2);
    });

    test('distribution', () async {
      MetricsApi api = fixture.getSut();
      api.distribution('key', value: 1.5);
      api.distribution('key', value: 2.4);

      Iterable<Metric> sentMetrics =
          fixture.mockHub.metricsAggregator!.buckets.values.first.values;
      expect(sentMetrics.first.type, MetricType.distribution);
      expect((sentMetrics.first as DistributionMetric).values, [1.5, 2.4]);
    });

    test('set', () async {
      MetricsApi api = fixture.getSut();
      api.set('key', value: 1);
      api.set('key', value: 2);
      // This is ignored as it's a repeated value
      api.set('key', value: 2);
      // This adds both an int and a crc32 of the string to the metric
      api.set('key', value: 4, stringValue: 'value');
      // No value provided. This does nothing
      api.set('key');
      // Empty String provided. This does nothing
      api.set('key', stringValue: '');

      Iterable<Metric> sentMetrics =
          fixture.mockHub.metricsAggregator!.buckets.values.first.values;
      expect(sentMetrics.first.type, MetricType.set);
      expect((sentMetrics.first as SetMetric).values, {1, 2, 4, 494360628});
    });
  });
}

class Fixture {
  final mockHub = MockHub();

  MetricsApi getSut() => MetricsApi(hub: mockHub);
}
