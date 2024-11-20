import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_hub.dart';

void main() {
  final fixture = Fixture();

  test('convert given startTimestamp to utc date time', () async {
    final nonUtcStartTimestamp = DateTime.now().toLocal();

    final sut = fixture.getSut(startTimestamp: nonUtcStartTimestamp);

    expect(nonUtcStartTimestamp.isUtc, false);
    expect(sut.startTimestamp.isUtc, true);
  });

  test('convert given endTimestamp to utc date time', () async {
    final nonUtcEndTimestamp = DateTime.now().toLocal();

    final sut = fixture.getSut(startTimestamp: nonUtcEndTimestamp);

    await sut.finish(endTimestamp: nonUtcEndTimestamp);

    expect(nonUtcEndTimestamp.isUtc, false);
    expect(sut.endTimestamp?.isUtc, true);
  });

  test('finish sets status', () async {
    final sut = fixture.getSut();

    await sut.finish(status: SpanStatus.aborted());

    expect(sut.status, SpanStatus.aborted());
  });

  test('finish sets end timestamp', () async {
    final sut = fixture.getSut();
    expect(sut.endTimestamp, isNull);
    await sut.finish();

    expect(sut.endTimestamp, isNotNull);
  });

  test('finish uses given end timestamp', () async {
    final sut = fixture.getSut();
    final endTimestamp = getUtcDateTime();

    expect(sut.endTimestamp, isNull);
    await sut.finish(endTimestamp: endTimestamp);
    expect(sut.endTimestamp, endTimestamp);
  });

  test('finish sets throwable', () async {
    final sut = fixture.getSut();
    sut.throwable = StateError('message');

    await sut.finish();

    expect(fixture.hub.spanContextCals, 1);
  });

  test(
      'finish does not set endTimestamp if given end timestamp is before start timestamp',
      () async {
    final sut = fixture.getSut();

    final invalidEndTimestamp = sut.startTimestamp.add(-Duration(hours: 1));
    await sut.finish(endTimestamp: invalidEndTimestamp);

    expect(sut.endTimestamp, isNot(equals(invalidEndTimestamp)));
  });

  test('span adds data', () {
    final sut = fixture.getSut();

    sut.setData('test', 'test');

    expect(sut.data['test'], 'test');
  });

  test('span removes data', () {
    final sut = fixture.getSut();

    sut.setData('test', 'test');
    sut.removeData('test');

    expect(sut.data['test'], isNull);
  });

  test('span sets origin', () {
    final sut = fixture.getSut();

    sut.origin = 'manual';

    expect(sut.origin, 'manual');
  });

  test('span adds tag', () {
    final sut = fixture.getSut();

    sut.setTag('test', 'test');

    expect(sut.tags['test'], 'test');
  });

  test('span removes tags', () {
    final sut = fixture.getSut();

    sut.setTag('test', 'test');
    sut.removeTag('test');

    expect(sut.tags['test'], isNull);
  });

  test('span starts child', () {
    final sut = fixture.getSut();

    final child = sut.startChild('op', description: 'desc');

    expect(child.context.parentSpanId, fixture.context.spanId);
    expect(child.context.operation, 'op');
    expect(child.context.description, 'desc');
  });

  test('span serializes', () async {
    fixture.hub.options.enableMetrics = true;
    fixture.hub.options.enableSpanLocalMetricAggregation = true;
    final sut = fixture.getSut();

    sut.setTag('test', 'test');
    sut.setData('test', 'test');
    sut.origin = 'manual';
    sut.localMetricsAggregator?.add(fakeMetric, 0);

    await sut.finish(status: SpanStatus.aborted());

    final map = sut.toJson();

    expect(map['start_timestamp'], isNotNull);
    expect(map['timestamp'], isNotNull);
    expect(map['data']['test'], 'test');
    expect(map['tags']['test'], 'test');
    expect(map['status'], 'aborted');
    expect(map['origin'], 'manual');
    expect(map['_metrics_summary'], isNotNull);
  });

  test('adding a metric after span finish does not serialize', () async {
    fixture.hub.options.enableMetrics = true;
    fixture.hub.options.enableSpanLocalMetricAggregation = true;
    final sut = fixture.getSut();
    await sut.finish(status: SpanStatus.aborted());
    sut.localMetricsAggregator?.add(fakeMetric, 0);

    expect(sut.toJson()['_metrics_summary'], isNull);
  });

  test('adding a metric when option is disabled does not serialize', () async {
    fixture.hub.options.enableMetrics = false;
    final sut = fixture.getSut();
    sut.localMetricsAggregator?.add(fakeMetric, 0);
    await sut.finish(status: SpanStatus.aborted());

    expect(sut.toJson()['_metrics_summary'], isNull);
  });

  test('finished returns false if not yet', () {
    final sut = fixture.getSut();

    expect(sut.finished, false);
  });

  test('finished returns true if finished', () async {
    final sut = fixture.getSut();
    await sut.finish();

    expect(sut.finished, true);
  });

  test('toSentryTrace returns trace header', () {
    final sut = fixture.getSut();

    expect(sut.toSentryTrace().value,
        '${sut.context.traceId}-${sut.context.spanId}-1');
  });

  test('finish isnt allowed to be called twice', () async {
    final sut = fixture.getSut();

    await sut.finish(status: SpanStatus.ok());
    await sut.finish(status: SpanStatus.cancelled());

    expect(sut.status, SpanStatus.ok());
  });

  test('removeData isnt allowed to be called after finishing', () async {
    final sut = fixture.getSut();

    sut.setData('key', 'value');
    await sut.finish(status: SpanStatus.ok());
    sut.removeData('key');

    expect(sut.data['key'], 'value');
  });

  test('removeTag isnt allowed to be called after finishing', () async {
    final sut = fixture.getSut();

    sut.setTag('key', 'value');
    await sut.finish(status: SpanStatus.ok());
    sut.removeTag('key');

    expect(sut.tags['key'], 'value');
  });

  test('setData isnt allowed to be called after finishing', () async {
    final sut = fixture.getSut();

    sut.setData('key', 'value');
    await sut.finish(status: SpanStatus.ok());
    sut.setData('key', 'value2');

    expect(sut.data['key'], 'value');
  });

  test('setTag isnt allowed to be called after finishing', () async {
    final sut = fixture.getSut();

    sut.setTag('key', 'value');
    await sut.finish(status: SpanStatus.ok());
    sut.setTag('key', 'value2');

    expect(sut.tags['key'], 'value');
  });

  test('startChild isnt allowed to be called after finishing', () async {
    final sut = fixture.getSut();

    await sut.finish(status: SpanStatus.ok());
    final span = sut.startChild('op');

    expect(NoOpSentrySpan(), span);
  });

  test(
      'startChild isnt allowed to be called if childs startTimestamp is before parents',
      () async {
    final parentStartTimestamp = DateTime.now();
    final childStartTimestamp = parentStartTimestamp.add(-Duration(hours: 1));
    final sut = fixture.getSut(startTimestamp: parentStartTimestamp);

    final span = sut.startChild('op', startTimestamp: childStartTimestamp);

    expect(NoOpSentrySpan(), span);
  });

  test('callback called on finish', () async {
    var numberOfCallbackCalls = 0;
    final sut =
        fixture.getSut(finishedCallback: ({DateTime? endTimestamp}) async {
      numberOfCallbackCalls += 1;
    });

    await sut.finish();

    expect(numberOfCallbackCalls, 1);
  });

  test('optional endTimestamp set instead of current time', () async {
    final sut = fixture.getSut();

    final endTimestamp = getUtcDateTime().add(Duration(days: 1));

    await sut.finish(endTimestamp: endTimestamp);

    expect(sut.endTimestamp, endTimestamp);
  });

  test('child span reschedule finish timer', () async {
    final sut = fixture.getSut(autoFinishAfter: Duration(seconds: 5));

    final currentTimer = fixture.tracer.autoFinishAfterTimer!;

    sut.scheduleFinish();

    final newTimer = fixture.tracer.autoFinishAfterTimer!;

    expect(currentTimer, isNot(equals(newTimer)));
  });

  test('takes origin from context', () async {
    final sut = fixture.getSut();
    expect(sut.origin, 'manual');
  });

  test('localMetricsAggregator is set when option is enabled', () async {
    fixture.hub.options.enableMetrics = true;
    fixture.hub.options.enableSpanLocalMetricAggregation = true;
    final sut = fixture.getSut();
    expect(fixture.hub.options.enableSpanLocalMetricAggregation, true);
    expect(sut.localMetricsAggregator, isNotNull);
  });

  test('localMetricsAggregator is null when option is disabled', () async {
    fixture.hub.options.enableSpanLocalMetricAggregation = false;
    final sut = fixture.getSut();
    expect(fixture.hub.options.enableSpanLocalMetricAggregation, false);
    expect(sut.localMetricsAggregator, null);
  });

  test('setMeasurement sets a measurement', () async {
    final sut = fixture.getSut();
    sut.setMeasurement("test", 1);
    expect(sut.tracer.measurements.containsKey("test"), true);
    expect(sut.tracer.measurements["test"]!.value, 1);
  });

  test('setMeasurement does not set a measurement if a span is finished',
      () async {
    final sut = fixture.getSut();
    await sut.finish();
    sut.setMeasurement("test", 1);
    expect(sut.tracer.measurements.isEmpty, true);
  });
}

class Fixture {
  final context = SentryTransactionContext('name', 'op', origin: 'manual');
  late SentryTracer tracer;
  final hub = MockHub();

  SentrySpan getSut({
    DateTime? startTimestamp,
    bool? sampled = true,
    OnFinishedCallback? finishedCallback,
    Duration? autoFinishAfter,
  }) {
    tracer = SentryTracer(context, hub, autoFinishAfter: autoFinishAfter);

    return SentrySpan(
      tracer,
      context,
      hub,
      startTimestamp: startTimestamp,
      samplingDecision: SentryTracesSamplingDecision(sampled!),
      finishedCallback: finishedCallback,
    );
  }
}
