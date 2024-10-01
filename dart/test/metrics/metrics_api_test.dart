import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/metrics/metric.dart';
import 'package:sentry/src/metrics/metrics_api.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import '../mocks/mock_hub.dart';
import '../test_utils.dart';

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

    test('timing emits distribution', () async {
      final delay = Duration(milliseconds: 100);
      final completer = Completer<void>();
      MetricsApi api = fixture.getSut();

      // The timing API tries to start a child span
      expect(fixture.mockHub.getSpanCalls, 0);
      api.timing('key',
          function: () => Future.delayed(delay, () => completer.complete()));
      expect(fixture.mockHub.getSpanCalls, 1);

      await completer.future;
      Iterable<Metric> sentMetrics =
          fixture.mockHub.metricsAggregator!.buckets.values.first.values;

      // The timing API emits a distribution metric
      expect(sentMetrics.first.type, MetricType.distribution);
      // The default unit is second
      expect(sentMetrics.first.unit, DurationSentryMeasurementUnit.second);
      // It awaits for the function completion, which means 100 milliseconds in
      // this case. Since the unit is second, its value (duration) is >= 0.1
      expect(
          (sentMetrics.first as DistributionMetric).values.first >= 0.1, true);
    });

    test('timing starts a span', () async {
      final delay = Duration(milliseconds: 100);
      final completer = Completer<void>();
      fixture._options.tracesSampleRate = 1;
      fixture._options.enableMetrics = true;
      MetricsApi api = fixture.getSut(hub: fixture.hub);

      // Start a transaction so that timing api can start a child span
      final transaction = fixture.hub.startTransaction(
        'name',
        'operation',
        bindToScope: true,
      ) as SentryTracer;
      expect(transaction.children, isEmpty);

      // Timing starts a span
      api.timing('my key',
          unit: DurationSentryMeasurementUnit.milliSecond,
          function: () => Future.delayed(delay, () => completer.complete()));
      final span = transaction.children.first;
      expect(span.finished, false);
      expect(span.context.operation, 'metric.timing');
      expect(span.context.description, 'my key');

      // Timing finishes the span when the function is finished, which takes 100 milliseconds
      await completer.future;
      expect(span.finished, true);
      final spanDuration = span.endTimestamp!.difference(span.startTimestamp);
      expect(spanDuration.inMilliseconds >= 100, true);
      await Future.delayed(Duration());

      Iterable<Metric> sentMetrics =
          fixture.hub.metricsAggregator!.buckets.values.first.values;

      // The emitted metric value should be aggregated in the span
      expect(span.localMetricsAggregator?.getSummaries(), isNotEmpty);
      // The emitted metric value should match the span duration
      expect(sentMetrics.first.unit, DurationSentryMeasurementUnit.milliSecond);
      // Duration.inMilliseconds returns an int, so we have to assert it
      expect((sentMetrics.first as DistributionMetric).values.first.toInt(),
          spanDuration.inMilliseconds);
    });
  });
}

class Fixture {
  final _options = defaultTestOptions();
  final mockHub = MockHub();
  late final hub = Hub(_options);

  MetricsApi getSut({Hub? hub}) => MetricsApi(hub: hub ?? mockHub);
}
