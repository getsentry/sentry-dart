import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import 'mocks/mock_hub.dart';

void main() {
  late Fixture fixture;

  setUp(() async {
    fixture = Fixture();
  });

  test('tracer sets name', () {
    final sut = fixture.getSut();

    expect(sut.name, 'name');
  });

  test('tracer sets sampled', () {
    final sut = fixture.getSut(sampled: false);

    expect(sut.sampled, false);
  });

  test('tracer finishes with status', () async {
    final sut = fixture.getSut();

    await sut.finish(status: SpanStatus.aborted());

    final tr = fixture.hub.captureTransactionCalls.first;
    final trace = tr.contexts.trace;

    expect(trace?.status.toString(), 'aborted');
  });

  test('tracer finishes unfinished spans', () async {
    final sut = fixture.getSut();
    sut.startChild('child');

    await sut.finish(status: SpanStatus.aborted());

    final tr = fixture.hub.captureTransactionCalls.first;
    final child = tr.spans.first;

    expect(child.status.toString(), 'deadline_exceeded');
  });

  test('tracer sets data to extra', () async {
    final sut = fixture.getSut();

    sut.setData('test', 'test');

    await sut.finish(status: SpanStatus.aborted());

    final tr = fixture.hub.captureTransactionCalls.first;

    expect(tr.extra?['test'], 'test');
  });

  test('tracer removes data to extra', () async {
    final sut = fixture.getSut();

    sut.setData('test', 'test');
    sut.removeData('test');

    await sut.finish(status: SpanStatus.aborted());

    final tr = fixture.hub.captureTransactionCalls.first;

    expect(tr.extra?['test'], isNull);
  });

  test('tracer starts child', () async {
    final sut = fixture.getSut();

    final child = sut.startChild('operation', description: 'desc');
    await child.finish();

    await sut.finish(status: SpanStatus.aborted());

    final tr = fixture.hub.captureTransactionCalls.first;
    final childSpan = tr.spans.first;

    expect(childSpan.context.description, 'desc');
    expect(childSpan.context.operation, 'operation');
  });

  test('tracer starts child with parentSpanId', () async {
    final sut = fixture.getSut();
    final parentId = SpanId.newId();
    final child = sut.startChildWithParentSpanId(
      parentId,
      'op',
      description: 'desc',
    );
    await child.finish();

    await sut.finish(status: SpanStatus.aborted());

    final tr = fixture.hub.captureTransactionCalls.first;
    final childSpan = tr.spans.first;

    expect(childSpan.context.description, 'desc');
    expect(childSpan.context.operation, 'op');
    expect(childSpan.context.parentSpanId.toString(), parentId.toString());
  });

  test('toSentryTrace returns trace header', () {
    final sut = fixture.getSut();

    expect(sut.toSentryTrace().value,
        '${sut.context.traceId}-${sut.context.spanId}-1');
  });

  test('tracer finishes after duration', () async {
    final sut = fixture.getSut();
    sut.finishAfter(Duration(milliseconds: 200), status: SpanStatus.ok());

    expect(sut.finished, false);
    await Future.delayed(Duration(milliseconds: 210));
    expect(sut.status, SpanStatus.ok());
    expect(sut.finished, true);
  });

  test('tracer finish needs child to finish', () async {
    final sut = fixture.getSut(waitForChildren: true);

    final child = sut.startChild('operation', description: 'description');

    await sut.finish();
    expect(sut.finished, false);

    await child.finish();
    expect(sut.finished, true);
  });

  test('tracer finish needs all children to finish', () async {
    final sut = fixture.getSut(waitForChildren: true);

    final childA = sut.startChild('operation-a', description: 'description');
    final childB = sut.startChild('operation-b', description: 'description');

    await sut.finish();
    expect(sut.finished, false);

    await childA.finish();
    expect(sut.finished, false);

    await childB.finish();
    expect(sut.finished, true);
  });

  test('tracer without finish will not be finished when children are finished',
      () async {
    final sut = fixture.getSut(waitForChildren: true);

    final childA = sut.startChild('operation-a', description: 'description');
    final childB = sut.startChild('operation-b', description: 'description');

    await childA.finish();
    expect(sut.finished, false);

    await childB.finish();
    expect(sut.finished, false);

    await sut.finish();
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
  final hub = MockHub();

  SentryTracer getSut({
    bool? sampled = true,
    bool waitForChildren = false,
  }) {
    final context = SentryTransactionContext(
      'name',
      'op',
      sampled: sampled,
    );
    return SentryTracer(context, hub, waitForChildren: waitForChildren);
  }
}
