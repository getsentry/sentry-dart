import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry/src/protocol/sentry_span.dart';
import 'package:test/test.dart';

import 'mocks/mock_hub.dart';

void main() {
  final fixture = Fixture();

  test('finish sets status', () async {
    final sut = fixture.getSut();

    await sut.finish(status: SpanStatus.aborted());

    expect(sut.status, SpanStatus.aborted());
  });

  test('finish sets end timestamp', () {
    final sut = fixture.getSut();
    expect(sut.endTimestamp, isNull);
    sut.finish();

    expect(sut.endTimestamp, isNotNull);
  });

  test('finish sets throwable', () {
    final sut = fixture.getSut();
    sut.throwable = StateError('message');

    sut.finish();

    expect(fixture.hub.spanContextCals, 1);
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
    final sut = fixture.getSut();

    sut.setTag('test', 'test');
    sut.setData('test', 'test');

    await sut.finish(status: SpanStatus.aborted());

    final map = sut.toJson();

    expect(map['start_timestamp'], isNotNull);
    expect(map['timestamp'], isNotNull);
    expect(map['data']['test'], 'test');
    expect(map['tags']['test'], 'test');
    expect(map['status'], 'aborted');
  });

  test('finished returns false if not yet', () {
    final sut = fixture.getSut();

    expect(sut.finished, false);
  });

  test('finished returns true if finished', () {
    final sut = fixture.getSut();
    sut.finish();

    expect(sut.finished, true);
  });

  test('toSentryTrace returns trace header', () {
    final sut = fixture.getSut();

    expect(sut.toSentryTrace().value,
        '${sut.context.traceId}-${sut.context.spanId}-1');
  });

  test('finishes after duration', () async {
    final sut = fixture.getSut();
    sut.finishAfter(Duration(milliseconds: 200), status: SpanStatus.ok());

    expect(sut.finished, false);
    await Future.delayed(Duration(milliseconds: 210));
    expect(sut.status, SpanStatus.ok());
    expect(sut.finished, true);
  });

  test('callback called on finish', () async {
    final sut = fixture.getSut();
    var numberOfCallbackCalls = 0;
    sut.finishedCallback = () {
      numberOfCallbackCalls += 1;
    };
    await sut.finish();

    expect(numberOfCallbackCalls, 1);
  });
}

class Fixture {
  final context = SentryTransactionContext(
    'name',
    'op',
  );
  late SentryTracer tracer;
  final hub = MockHub();

  SentrySpan getSut({bool? sampled = true}) {
    tracer = SentryTracer(context, hub);

    return SentrySpan(
      tracer,
      context,
      hub,
      sampled: sampled,
    );
  }
}
