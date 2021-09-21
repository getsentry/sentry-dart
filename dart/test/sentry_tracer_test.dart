import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import 'mocks/mock_hub.dart';

void main() {
  final fixture = Fixture();

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
    expect(childSpan.context.operation, 'operation');
    expect(childSpan.context.parentSpanId.toString(), parentId.toString());
  });
}

class Fixture {
  final hub = MockHub();

  SentryTracer getSut({
    bool? sampled = true,
  }) {
    final context = SentryTransactionContext(
      'name',
      'op',
      sampled: sampled,
    );
    return SentryTracer(
      context,
      hub,
    );
  }
}
