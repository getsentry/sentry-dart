import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_hub.dart';
import 'test_utils.dart';

void main() {
  final fixture = Fixture();

  SentryTracer _createTracer({
    bool? sampled = true,
    Hub? hub,
  }) {
    final context = SentryTransactionContext(
      'name',
      'op',
      samplingDecision: SentryTracesSamplingDecision(sampled!),
      transactionNameSource: SentryTransactionNameSource.component,
    );
    return SentryTracer(context, hub ?? MockHub());
  }

  test('toJson serializes', () async {
    fixture.options.enableSpanLocalMetricAggregation = true;
    fixture.options.enableMetrics = true;

    final tracer = _createTracer(hub: fixture.hub);
    tracer.localMetricsAggregator?.add(fakeMetric, 0);

    final child = tracer.startChild('child');
    await child.finish();
    await tracer.finish();

    final sut = fixture.getSut(tracer);
    final map = sut.toJson();

    expect(map['type'], 'transaction');
    expect(map['start_timestamp'], isNotNull);
    expect(map['spans'], isNotNull);
    expect(map['transaction_info']['source'], 'component');
    expect(map['_metrics_summary'], isNotNull);
  });

  test('returns finished if it is', () async {
    final tracer = _createTracer();
    final child = tracer.startChild('child');
    await child.finish();
    await tracer.finish();

    final sut = fixture.getSut(tracer);

    expect(sut.finished, true);
  });

  test('returns sampled if theres context', () async {
    final tracer = _createTracer(sampled: true);
    final child = tracer.startChild('child');
    await child.finish();
    await tracer.finish();

    final sut = fixture.getSut(tracer);

    expect(sut.sampled, true);
  });

  test('returns sampled false if not sampled', () async {
    final tracer = _createTracer(sampled: false);
    final child = tracer.startChild('child');
    await child.finish();
    await tracer.finish();

    final sut = fixture.getSut(tracer);

    expect(sut.sampled, false);
  });

  test('add a metric to localAggregator adds it to metricSummary', () async {
    fixture.options.enableSpanLocalMetricAggregation = true;
    fixture.options.enableMetrics = true;

    final tracer = _createTracer(hub: fixture.hub)
      ..localMetricsAggregator?.add(fakeMetric, 0);
    await tracer.finish();

    final sut = fixture.getSut(tracer);
    expect(sut.metricSummaries, isNotEmpty);
  });

  test('add metric after creation does not add it to metricSummary', () async {
    fixture.options.enableSpanLocalMetricAggregation = true;
    fixture.options.enableMetrics = true;

    final tracer = _createTracer(hub: fixture.hub);
    await tracer.finish();
    final sut = fixture.getSut(tracer);
    tracer.localMetricsAggregator?.add(fakeMetric, 0);

    expect(sut.metricSummaries, isEmpty);
  });

  test('metricSummary is null by default', () async {
    final tracer = _createTracer();
    await tracer.finish();
    final sut = fixture.getSut(tracer);
    expect(sut.metricSummaries, null);
  });
}

class Fixture {
  final SentryOptions options = defaultTestOptions();
  late final Hub hub = Hub(options);

  SentryTransaction getSut(SentryTracer tracer) {
    return SentryTransaction(tracer);
  }
}
