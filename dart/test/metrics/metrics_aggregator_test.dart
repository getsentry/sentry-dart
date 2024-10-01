import 'package:sentry/sentry.dart';
import 'package:sentry/src/metrics/metric.dart';
import 'package:sentry/src/metrics/metrics_aggregator.dart';
import 'package:test/test.dart';

import '../mocks/mock_hub.dart';
import '../test_utils.dart';

void main() {
  group('emit', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('counter', () async {
      final MetricsAggregator sut = fixture.getSut();
      final String key = 'metric key';
      final double value = 5;
      final SentryMeasurementUnit unit = DurationSentryMeasurementUnit.minute;
      final Map<String, String> tags = {'tag1': 'val1', 'tag2': 'val2'};
      sut.emit(MetricType.counter, key, value, unit, tags);

      final metricsCaptured = sut.buckets.values.first.values;
      expect(metricsCaptured.length, 1);
      expect(metricsCaptured.first, isA<CounterMetric>());
      expect(metricsCaptured.first.type, MetricType.counter);
      expect(metricsCaptured.first.key, key);
      expect((metricsCaptured.first as CounterMetric).value, value);
      expect(metricsCaptured.first.unit, unit);
      expect(metricsCaptured.first.tags, tags);
    });

    test('gauge', () async {
      final MetricsAggregator sut = fixture.getSut();
      sut.testEmit(type: MetricType.gauge);

      final metricsCaptured = sut.buckets.values.first.values;
      expect(metricsCaptured.first, isA<GaugeMetric>());
      expect(metricsCaptured.first.type, MetricType.gauge);
    });

    test('distribution', () async {
      final MetricsAggregator sut = fixture.getSut();
      sut.testEmit(type: MetricType.distribution);

      final metricsCaptured = sut.buckets.values.first.values;
      expect(metricsCaptured.first, isA<DistributionMetric>());
      expect(metricsCaptured.first.type, MetricType.distribution);
    });

    test('set', () async {
      final MetricsAggregator sut = fixture.getSut();
      sut.testEmit(type: MetricType.set);

      final metricsCaptured = sut.buckets.values.first.values;
      expect(metricsCaptured.first, isA<SetMetric>());
      expect(metricsCaptured.first.type, MetricType.set);
    });
  });

  group('span local aggregation', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('emit calls add', () async {
      final MetricsAggregator sut = fixture.getSut(hub: fixture.hub);
      final t = fixture.hub.startTransaction('test', 'op', bindToScope: true);

      var spanSummary = t.localMetricsAggregator?.getSummaries().values;
      expect(spanSummary, isEmpty);

      sut.testEmit();

      spanSummary = t.localMetricsAggregator?.getSummaries().values;
      expect(spanSummary, isNotEmpty);
    });

    test('emit counter', () async {
      final MetricsAggregator sut = fixture.getSut(hub: fixture.hub);
      final t = fixture.hub.startTransaction('test', 'op', bindToScope: true);

      sut.testEmit(type: MetricType.counter, value: 1);
      sut.testEmit(type: MetricType.counter, value: 4);

      final spanSummary = t.localMetricsAggregator?.getSummaries().values.first;
      expect(spanSummary!.length, 1);
      expect(spanSummary.first.sum, 5);
      expect(spanSummary.first.min, 1);
      expect(spanSummary.first.max, 4);
      expect(spanSummary.first.count, 2);
      expect(spanSummary.first.tags, mockTags);
    });

    test('emit distribution', () async {
      final MetricsAggregator sut = fixture.getSut(hub: fixture.hub);
      final t = fixture.hub.startTransaction('test', 'op', bindToScope: true);

      sut.testEmit(type: MetricType.distribution, value: 1);
      sut.testEmit(type: MetricType.distribution, value: 4);

      final spanSummary = t.localMetricsAggregator?.getSummaries().values.first;
      expect(spanSummary!.length, 1);
      expect(spanSummary.first.sum, 5);
      expect(spanSummary.first.min, 1);
      expect(spanSummary.first.max, 4);
      expect(spanSummary.first.count, 2);
      expect(spanSummary.first.tags, mockTags);
    });

    test('emit gauge', () async {
      final MetricsAggregator sut = fixture.getSut(hub: fixture.hub);
      final t = fixture.hub.startTransaction('test', 'op', bindToScope: true);

      sut.testEmit(type: MetricType.gauge, value: 1);
      sut.testEmit(type: MetricType.gauge, value: 4);

      final spanSummary = t.localMetricsAggregator?.getSummaries().values.first;
      expect(spanSummary!.length, 1);
      expect(spanSummary.first.sum, 5);
      expect(spanSummary.first.min, 1);
      expect(spanSummary.first.max, 4);
      expect(spanSummary.first.count, 2);
      expect(spanSummary.first.tags, mockTags);
    });

    test('emit set', () async {
      final MetricsAggregator sut = fixture.getSut(hub: fixture.hub);
      final t = fixture.hub.startTransaction('test', 'op', bindToScope: true);

      sut.testEmit(type: MetricType.set, value: 1);
      sut.testEmit(type: MetricType.set, value: 4);

      final spanSummary = t.localMetricsAggregator?.getSummaries().values.first;
      expect(spanSummary!.length, 1);
      expect(spanSummary.first.sum, 2);
      expect(spanSummary.first.min, 1);
      expect(spanSummary.first.max, 1);
      expect(spanSummary.first.count, 2);
      expect(spanSummary.first.tags, mockTags);
    });
  });

  group('emit in same time bucket', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('same metric with different keys emit different metrics', () async {
      final MetricsAggregator sut = fixture.getSut();
      sut.testEmit(key: mockKey);
      sut.testEmit(key: mockKey2);

      final timeBuckets = sut.buckets;
      final bucket = timeBuckets.values.first;

      expect(bucket.length, 2);
      expect(bucket.values.firstWhere((e) => e.key == mockKey), isNotNull);
      expect(bucket.values.firstWhere((e) => e.key == mockKey2), isNotNull);
    });

    test('same metric with different units emit different metrics', () async {
      final MetricsAggregator sut = fixture.getSut();
      sut.testEmit(unit: mockUnit);
      sut.testEmit(unit: mockUnit2);

      final timeBuckets = sut.buckets;
      final bucket = timeBuckets.values.first;

      expect(bucket.length, 2);
      expect(bucket.values.firstWhere((e) => e.unit == mockUnit), isNotNull);
      expect(bucket.values.firstWhere((e) => e.unit == mockUnit2), isNotNull);
    });

    test('same metric with different tags emit different metrics', () async {
      final MetricsAggregator sut = fixture.getSut();
      sut.testEmit(tags: mockTags);
      sut.testEmit(tags: mockTags2);

      final timeBuckets = sut.buckets;
      final bucket = timeBuckets.values.first;

      expect(bucket.length, 2);
      expect(bucket.values.firstWhere((e) => e.tags == mockTags), isNotNull);
      expect(bucket.values.firstWhere((e) => e.tags == mockTags2), isNotNull);
    });

    test('increment same metric emit only one counter', () async {
      final MetricsAggregator sut = fixture.getSut();
      sut.testEmit(type: MetricType.counter, value: 1);
      sut.testEmit(type: MetricType.counter, value: 2);

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
      sut.testEmit();
      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(9999);
      sut.testEmit();

      final timeBuckets = sut.buckets;
      expect(timeBuckets.length, 1);
    });

    test('same metric in >= 10 seconds interval emit two metrics', () async {
      final MetricsAggregator sut = fixture.getSut();
      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(0);
      sut.testEmit();
      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(10000);
      sut.testEmit();
      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(20000);
      sut.testEmit();

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
      sut.testEmit();
      expect(sut.flushCompleter, isNotNull);
    });

    test('flush calls hub captureMetrics', () async {
      final MetricsAggregator sut = fixture.getSut();

      // emit a metric
      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(0);
      sut.testEmit();
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
      sut.testEmit();
      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(10000);
      expect(sut.flushCompleter, isNotNull);
      await sut.flushCompleter!.future;
      expect(sut.flushCompleter, isNull);
    });

    test('flush schedules flushing if there are other metrics', () async {
      final MetricsAggregator sut = fixture.getSut();

      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(0);
      sut.testEmit();
      fixture.options.clock = () => DateTime.fromMillisecondsSinceEpoch(10000);
      sut.testEmit();
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
      sut.testEmit();
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
      sut.testEmit();

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
      sut.testEmit();

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

    test('close flushes everything', () async {
      final MetricsAggregator sut = fixture.getSut();
      sut.testEmit();
      sut.testEmit(type: MetricType.gauge);
      // We have some metrics, but we don't flush them, yet
      await sut.flushCompleter!.future;
      expect(fixture.mockHub.captureMetricsCalls, isEmpty);

      // Closing the aggregator. Flush everything
      sut.close();
      expect(fixture.mockHub.captureMetricsCalls, isNotEmpty);
      expect(sut.buckets, isEmpty);
    });
  });

  group('beforeMetric', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('emits if not set', () async {
      final MetricsAggregator sut = fixture.getSut(maxWeight: 4);
      sut.testEmit(key: 'key1');
      final metricsCaptured = sut.buckets.values.first.values;
      expect(metricsCaptured.length, 1);
      expect(metricsCaptured.first.key, 'key1');
    });

    test('drops if it return false', () async {
      final MetricsAggregator sut = fixture.getSut(maxWeight: 4);
      fixture.options.beforeMetricCallback = (key, {tags}) => key != 'key2';
      sut.testEmit(key: 'key1');
      sut.testEmit(key: 'key2');
      final metricsCaptured = sut.buckets.values.first.values;
      expect(metricsCaptured.length, 1);
      expect(metricsCaptured.first.key, 'key1');
    });

    test('emits if it return true', () async {
      final MetricsAggregator sut = fixture.getSut(maxWeight: 4);
      fixture.options.beforeMetricCallback = (key, {tags}) => true;
      sut.testEmit(key: 'key1');
      sut.testEmit(key: 'key2');
      final metricsCaptured = sut.buckets.values.first.values;
      expect(metricsCaptured.length, 2);
      expect(metricsCaptured.first.key, 'key1');
      expect(metricsCaptured.last.key, 'key2');
    });

    test('emits if it throws', () async {
      fixture.options.automatedTestMode = false;
      final MetricsAggregator sut = fixture.getSut(maxWeight: 4);
      fixture.options.beforeMetricCallback = (key, {tags}) => throw Exception();
      sut.testEmit(key: 'key1');
      sut.testEmit(key: 'key2');
      final metricsCaptured = sut.buckets.values.first.values;
      expect(metricsCaptured.length, 2);
      expect(metricsCaptured.first.key, 'key1');
      expect(metricsCaptured.last.key, 'key2');
    });
  });

  group('overweight', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('flush if exceeds maxWeight', () async {
      final MetricsAggregator sut = fixture.getSut(maxWeight: 4);
      sut.testEmit(type: MetricType.counter, key: 'key1');
      sut.testEmit(type: MetricType.counter, key: 'key2');
      sut.testEmit(type: MetricType.counter, key: 'key3');
      await sut.flushCompleter!.future;
      expect(fixture.mockHub.captureMetricsCalls, isEmpty);
      // After the 4th metric is emitted, the aggregator flushes immediately
      sut.testEmit(type: MetricType.counter, key: 'key4');
      expect(fixture.mockHub.captureMetricsCalls, isNotEmpty);
    });

    test('does not flush if not exceeds maxWeight', () async {
      final MetricsAggregator sut = fixture.getSut(maxWeight: 2);
      // We are emitting the same metric, so no weight is added
      sut.testEmit(type: MetricType.counter);
      sut.testEmit(type: MetricType.counter);
      sut.testEmit(type: MetricType.counter);
      sut.testEmit(type: MetricType.counter);
      await sut.flushCompleter!.future;
      expect(fixture.mockHub.captureMetricsCalls, isEmpty);
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
  final options = defaultTestOptions();
  final mockHub = MockHub();
  late final hub = Hub(options);

  Fixture() {
    options.tracesSampleRate = 1;
    options.enableMetrics = true;
    options.enableSpanLocalMetricAggregation = true;
  }

  MetricsAggregator getSut({
    Hub? hub,
    Duration flushInterval = const Duration(milliseconds: 1),
    int flushShiftMs = 0,
    int maxWeight = 100000,
  }) {
    return MetricsAggregator(
        hub: hub ?? mockHub,
        options: options,
        flushInterval: flushInterval,
        flushShiftMs: flushShiftMs,
        maxWeight: maxWeight);
  }
}

extension _MetricsAggregatorUtils on MetricsAggregator {
  testEmit({
    MetricType type = MetricType.counter,
    String key = mockKey,
    double value = mockValue,
    SentryMeasurementUnit unit = mockUnit,
    Map<String, String> tags = mockTags,
  }) {
    emit(type, key, value, unit, tags);
  }
}
