import 'package:sentry/sentry.dart';
import 'package:sentry/src/metrics/metric.dart';
import 'package:sentry/src/metrics/metrics_aggregator.dart';
import 'package:test/test.dart';

import '../mocks.dart';
import '../mocks/mock_hub.dart';

void main() {
  group('apis', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('increment emits counter metric', () async {
      final MetricsAggregator sut = fixture.getSut();
      final String key = 'metric key';
      final double value = 5;
      final SentryMeasurementUnit unit = DurationSentryMeasurementUnit.minute;
      final Map<String, String> tags = {'tag1': 'val1', 'tag2': 'val2'};
      sut.increment(key, value, unit, tags);

      final metricsCaptured = sut.buckets.values.first.values;
      expect(metricsCaptured.length, 1);
      expect(metricsCaptured.first.type, MetricType.counter);
      expect(metricsCaptured.first.key, key);
      expect((metricsCaptured.first as CounterMetric).value, value);
      expect(metricsCaptured.first.unit, unit);
      expect(metricsCaptured.first.tags, tags);
    });
  });

  group('emit in same time bucket', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('same metric with different keys emit different metrics', () async {
      final MetricsAggregator sut = fixture.getSut();
      sut.testIncrement(key: mockKey);
      sut.testIncrement(key: mockKey2);

      final timeBuckets = sut.buckets;
      final bucket = timeBuckets.values.first;

      expect(bucket.length, 2);
      expect(bucket.values.firstWhere((e) => e.key == mockKey), isNotNull);
      expect(bucket.values.firstWhere((e) => e.key == mockKey2), isNotNull);
    });

    test('same metric with different units emit different metrics', () async {
      final MetricsAggregator sut = fixture.getSut();
      sut.testIncrement(unit: mockUnit);
      sut.testIncrement(unit: mockUnit2);

      final timeBuckets = sut.buckets;
      final bucket = timeBuckets.values.first;

      expect(bucket.length, 2);
      expect(bucket.values.firstWhere((e) => e.unit == mockUnit), isNotNull);
      expect(bucket.values.firstWhere((e) => e.unit == mockUnit2), isNotNull);
    });

    test('same metric with different tags emit different metrics', () async {
      final MetricsAggregator sut = fixture.getSut();
      sut.testIncrement(tags: mockTags);
      sut.testIncrement(tags: mockTags2);

      final timeBuckets = sut.buckets;
      final bucket = timeBuckets.values.first;

      expect(bucket.length, 2);
      expect(bucket.values.firstWhere((e) => e.tags == mockTags), isNotNull);
      expect(bucket.values.firstWhere((e) => e.tags == mockTags2), isNotNull);
    });

    test('increment same metric emit only one counter', () async {
      final MetricsAggregator sut = fixture.getSut();
      sut.testIncrement(value: 1);
      sut.testIncrement(value: 2);

      final timeBuckets = sut.buckets;
      final bucket = timeBuckets.values.first;

      expect(bucket.length, 1);
      expect((bucket.values.first as CounterMetric).value, 3);
    });
  });

  group('time buckets', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('same metric in < 10 seconds interval emit only one metric', () async {
      final MetricsAggregator sut = fixture.getSut();
      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(0);
      sut.testIncrement();
      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(9999);
      sut.testIncrement();

      final timeBuckets = sut.buckets;
      expect(timeBuckets.length, 1);
    });

    test('same metric in >= 10 seconds interval emit two metrics', () async {
      final MetricsAggregator sut = fixture.getSut();
      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(0);
      sut.testIncrement();
      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(10000);
      sut.testIncrement();
      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(20000);
      sut.testIncrement();

      final timeBuckets = sut.buckets;
      expect(timeBuckets.length, 3);
    });
  });

  group('flush metrics', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('emitting a metric schedules flushing', () async {
      final MetricsAggregator sut = fixture.getSut();

      expect(sut.flushCompleter, isNull);
      sut.testIncrement();
      expect(sut.flushCompleter, isNotNull);
    });

    test('flush calls hub captureMetrics', () async {
      final MetricsAggregator sut = fixture.getSut();

      // emit a counter metric
      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(0);
      sut.testIncrement();
      expect(fixture.mockHub.captureMetricsCalls, isEmpty);

      // mock clock to allow metric time aggregation
      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(10000);
      // wait for flush
      await sut.flushCompleter!.future;
      expect(fixture.mockHub.captureMetricsCalls, isNotEmpty);

      Map<int, Iterable<Metric>> capturedMetrics =
          fixture.mockHub.captureMetricsCalls.first.metricsBuckets;
      Metric capturedMetric = capturedMetrics.values.first.first;
      expect(capturedMetric.key, mockKey);
    });

    test('flush don\'t schedules flushing if no other metrics', () async {
      final MetricsAggregator sut = fixture.getSut();

      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(0);
      sut.testIncrement();
      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(10000);
      expect(sut.flushCompleter, isNotNull);
      await sut.flushCompleter!.future;
      expect(sut.flushCompleter, isNull);
    });

    test('flush schedules flushing if there are other metrics', () async {
      final MetricsAggregator sut = fixture.getSut();

      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(0);
      sut.testIncrement();
      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(10000);
      sut.testIncrement();
      expect(sut.flushCompleter, isNotNull);
      await sut.flushCompleter!.future;
      // we expect the aggregator flushed metrics and schedules flushing again
      expect(fixture.mockHub.captureMetricsCalls, isNotEmpty);
      expect(sut.flushCompleter, isNotNull);
    });

    test('flush schedules flushing if no metric was captured', () async {
      final MetricsAggregator sut =
          fixture.getSut(flushInterval: Duration(milliseconds: 100));

      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(10000);
      sut.testIncrement();
      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(10050);

      expect(sut.flushCompleter, isNotNull);
      await sut.flushCompleter!.future;
      // we expect the aggregator didn't flush anything and schedules flushing
      expect(fixture.mockHub.captureMetricsCalls, isEmpty);
      expect(sut.flushCompleter, isNotNull);
    });

    test('flush ignores last 10 seconds', () async {
      final MetricsAggregator sut = fixture.getSut();

      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(10000);
      sut.testIncrement();

      // The 10 second bucket is not finished, so it shouldn't capture anything
      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(19999);
      await sut.flushCompleter!.future;
      expect(fixture.mockHub.captureMetricsCalls, isEmpty);

      // The 10 second bucket finished, so it should capture metrics
      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(20000);
      await sut.flushCompleter!.future;
      expect(fixture.mockHub.captureMetricsCalls, isNotEmpty);
    });

    test('flush ignores last flushShiftMs milliseconds', () async {
      final MetricsAggregator sut = fixture.getSut(flushShiftMs: 4000);

      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(10000);
      sut.testIncrement();

      // The 10 second bucket is not finished, so it shouldn't capture anything
      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(19999);
      await sut.flushCompleter!.future;
      expect(fixture.mockHub.captureMetricsCalls, isEmpty);

      // The 10 second bucket finished, but flushShiftMs didn't pass, so it shouldn't capture anything
      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(23999);
      await sut.flushCompleter!.future;
      expect(fixture.mockHub.captureMetricsCalls, isEmpty);

      // The 10 second bucket finished and flushShiftMs passed, so it should capture metrics
      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(24000);
      await sut.flushCompleter!.future;
      expect(fixture.mockHub.captureMetricsCalls, isNotEmpty);
    });
  });
}

const String mockKey = 'metric key';
const String mockKey2 = 'metric key 2';
const double mockValue = 5;
const SentryMeasurementUnit mockUnit = DurationSentryMeasurementUnit.minute;
const SentryMeasurementUnit mockUnit2 = DurationSentryMeasurementUnit.second;
const Map<String, String> mockTags = {'tag1': 'val1', 'tag2': 'val2'};
const Map<String, String> mockTags2 = {'tag1': 'val1'};
final DateTime mockTimestamp = DateTime.fromMillisecondsSinceEpoch(1);

class Fixture {
  final options = SentryOptions(dsn: fakeDsn);
  final mockHub = MockHub();

  MetricsAggregator getSut({
    Duration flushInterval = const Duration(milliseconds: 1),
    int flushShiftMs = 0,
  }) {
    return MetricsAggregator(
        hub: mockHub,
        options: options,
        flushInterval: flushInterval,
        flushShiftMs: flushShiftMs);
  }
}

extension _MetricsAggregatorUtils on MetricsAggregator {
  testIncrement({
    String key = mockKey,
    double value = mockValue,
    SentryMeasurementUnit unit = mockUnit,
    Map<String, String> tags = mockTags,
  }) {
    increment(key, value, unit, tags);
  }
}
