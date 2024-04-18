import 'package:sentry/sentry.dart';
import 'package:sentry/src/metrics/metric.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import 'metrics_aggregator_test.dart';

void main() {
  group('fromType', () {
    test('counter creates a CounterMetric', () async {
      final Metric metric = Metric.fromType(
          type: MetricType.counter,
          key: mockKey,
          value: 1,
          unit: mockUnit,
          tags: mockTags);
      expect(metric, isA<CounterMetric>());
    });

    test('gauge creates a GaugeMetric', () async {
      final Metric metric = Metric.fromType(
          type: MetricType.gauge,
          key: mockKey,
          value: 1,
          unit: mockUnit,
          tags: mockTags);
      expect(metric, isA<GaugeMetric>());
    });

    test('distribution creates a DistributionMetric', () async {
      final Metric metric = Metric.fromType(
          type: MetricType.distribution,
          key: mockKey,
          value: 1,
          unit: mockUnit,
          tags: mockTags);
      expect(metric, isA<DistributionMetric>());
    });

    test('set creates a SetMetric', () async {
      final Metric metric = Metric.fromType(
          type: MetricType.set,
          key: mockKey,
          value: 1,
          unit: mockUnit,
          tags: mockTags);
      expect(metric, isA<SetMetric>());
    });
  });

  group('Encode to statsd', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('encode CounterMetric', () async {
      final int bucketKey = 10;
      final expectedStatsd =
          'key_metric_@hour:2.1|c|#tag1:tag\\u{2c} value 1,key2:&@"13/-d_s|T10';
      final actualStatsd = fixture.counterMetric.encodeToStatsd(bucketKey);
      expect(actualStatsd, expectedStatsd);
    });

    test('sanitize name', () async {
      final metric = Metric.fromType(
        type: MetricType.counter,
        value: 2.1,
        key: 'key£ - @# metric!',
        unit: DurationSentryMeasurementUnit.day,
        tags: {},
      );

      final expectedStatsd = 'key_-_metric_@day:2.1|c|T10';
      expect(metric.encodeToStatsd(10), expectedStatsd);
    });

    test('sanitize unit', () async {
      final metric = Metric.fromType(
        type: MetricType.counter,
        value: 2.1,
        key: 'key',
        unit: CustomSentryMeasurementUnit('weird-measurement name!'),
        tags: {},
      );

      final expectedStatsd = 'key@weirdmeasurementname:2.1|c|T10';
      expect(metric.encodeToStatsd(10), expectedStatsd);
    });

    test('sanitize tags', () async {
      final metric = Metric.fromType(
        type: MetricType.counter,
        value: 2.1,
        key: 'key',
        unit: DurationSentryMeasurementUnit.day,
        tags: {'tag1': 'tag, value 1', 'key 2': '&@"13/-d_s'},
      );

      final expectedStatsd =
          'key@day:2.1|c|#tag1:tag\\u{2c} value 1,key2:&@"13/-d_s|T10';
      expect(metric.encodeToStatsd(10), expectedStatsd);
    });
  });

  group('getCompositeKey', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('escapes commas from tags', () async {
      final Iterable<String> tags = fixture.counterMetric.tags.values;
      final joinedTags = tags.join();
      final Iterable<String> expectedTags =
          tags.map((e) => e.replaceAll(',', '\\,'));
      final actualKey = fixture.counterMetric.getCompositeKey();

      expect(joinedTags.contains(','), true);
      expect(joinedTags.contains('\\,'), false);
      expect(actualKey.contains('\\,'), true);
      for (var tag in expectedTags) {
        expect(actualKey.contains(tag), true);
      }
    });

    test('CounterMetric', () async {
      final expectedKey =
          'c_key metric!_hour_tag1=tag\\, value 1,key 2=&@"13/-d_s';
      final actualKey = fixture.counterMetric.getCompositeKey();
      expect(actualKey, expectedKey);
    });

    test('GaugeMetric', () async {
      final expectedKey =
          'g_key metric!_hour_tag1=tag\\, value 1,key 2=&@"13/-d_s';
      final actualKey = fixture.gaugeMetric.getCompositeKey();
      expect(actualKey, expectedKey);
    });

    test('DistributionMetric', () async {
      final expectedKey =
          'd_key metric!_hour_tag1=tag\\, value 1,key 2=&@"13/-d_s';
      final actualKey = fixture.distributionMetric.getCompositeKey();
      expect(actualKey, expectedKey);
    });

    test('SetMetric', () async {
      final expectedKey =
          's_key metric!_hour_tag1=tag\\, value 1,key 2=&@"13/-d_s';
      final actualKey = fixture.setMetric.getCompositeKey();
      expect(actualKey, expectedKey);
    });
  });

  group('getSpanAggregationKey', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('CounterMetric', () async {
      final expectedKey = 'c:key metric!@hour';
      final actualKey = fixture.counterMetric.getSpanAggregationKey();
      expect(actualKey, expectedKey);
    });

    test('GaugeMetric', () async {
      final expectedKey = 'g:key metric!@hour';
      final actualKey = fixture.gaugeMetric.getSpanAggregationKey();
      expect(actualKey, expectedKey);
    });

    test('DistributionMetric', () async {
      final expectedKey = 'd:key metric!@hour';
      final actualKey = fixture.distributionMetric.getSpanAggregationKey();
      expect(actualKey, expectedKey);
    });

    test('SetMetric', () async {
      final expectedKey = 's:key metric!@hour';
      final actualKey = fixture.setMetric.getSpanAggregationKey();
      expect(actualKey, expectedKey);
    });
  });

  group('getWeight', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('counter always returns 1', () async {
      final CounterMetric metric = fixture.counterMetric;
      expect(metric.getWeight(), 1);
      metric.add(5);
      metric.add(2);
      expect(metric.getWeight(), 1);
    });

    test('gauge always returns 5', () async {
      final GaugeMetric metric = fixture.gaugeMetric;
      expect(metric.getWeight(), 5);
      metric.add(5);
      metric.add(2);
      expect(metric.getWeight(), 5);
    });

    test('distribution returns number of values', () async {
      final DistributionMetric metric = fixture.distributionMetric;
      expect(metric.getWeight(), 1);
      metric.add(5);
      // Repeated values are counted
      metric.add(5);
      expect(metric.getWeight(), 3);
    });

    test('set returns number of unique values', () async {
      final SetMetric metric = fixture.setMetric;
      expect(metric.getWeight(), 1);
      metric.add(5);
      // Repeated values are not counted
      metric.add(5);
      expect(metric.getWeight(), 2);
    });
  });

  group('add', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('counter increments', () async {
      final CounterMetric metric = fixture.counterMetric;
      expect(metric.value, 2.1);
      metric.add(5);
      metric.add(2);
      expect(metric.value, 9.1);
    });

    test('gauge stores min, max, last, sum and count', () async {
      final GaugeMetric metric = fixture.gaugeMetric;
      expect(metric.minimum, 2.1);
      expect(metric.maximum, 2.1);
      expect(metric.last, 2.1);
      expect(metric.sum, 2.1);
      expect(metric.count, 1);
      metric.add(1.4);
      metric.add(5.4);
      expect(metric.minimum, 1.4);
      expect(metric.maximum, 5.4);
      expect(metric.last, 5.4);
      expect(metric.sum, 8.9);
      expect(metric.count, 3);
    });

    test('distribution stores all values', () async {
      final DistributionMetric metric = fixture.distributionMetric;
      metric.add(2);
      metric.add(4);
      metric.add(4);
      expect(metric.values, [2.1, 2, 4, 4]);
    });

    test('set stores unique int values', () async {
      final SetMetric metric = fixture.setMetric;
      metric.add(5);
      // Repeated values are not counted
      metric.add(5);
      expect(metric.values, {2, 5});
    });
  });
}

class Fixture {
  // We use a fractional number because on some platforms converting '2' to
  //  string return '2', while others '2.0', and we'd have issues testing.
  final CounterMetric counterMetric = Metric.fromType(
    type: MetricType.counter,
    value: 2.1,
    key: 'key metric!',
    unit: DurationSentryMeasurementUnit.hour,
    tags: {'tag1': 'tag, value 1', 'key 2': '&@"13/-d_s'},
  ) as CounterMetric;

  final GaugeMetric gaugeMetric = Metric.fromType(
    type: MetricType.gauge,
    value: 2.1,
    key: 'key metric!',
    unit: DurationSentryMeasurementUnit.hour,
    tags: {'tag1': 'tag, value 1', 'key 2': '&@"13/-d_s'},
  ) as GaugeMetric;

  final DistributionMetric distributionMetric = Metric.fromType(
    type: MetricType.distribution,
    value: 2.1,
    key: 'key metric!',
    unit: DurationSentryMeasurementUnit.hour,
    tags: {'tag1': 'tag, value 1', 'key 2': '&@"13/-d_s'},
  ) as DistributionMetric;

  final SetMetric setMetric = Metric.fromType(
    type: MetricType.set,
    value: 2.1,
    key: 'key metric!',
    unit: DurationSentryMeasurementUnit.hour,
    tags: {'tag1': 'tag, value 1', 'key 2': '&@"13/-d_s'},
  ) as SetMetric;
}
