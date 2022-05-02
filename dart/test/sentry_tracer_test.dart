import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry/src/utils.dart';
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

  test('tracer finishes with end timestamp', () async {
    final sut = fixture.getSut();
    final endTimestamp = getUtcDateTime();

    await sut.finish(endTimestamp: endTimestamp);

    expect(sut.endTimestamp, endTimestamp);
  });

  test(
      'tracer finish sets given end timestamp to all children while finishing them',
      () async {
    final sut = fixture.getSut();

    final childA = sut.startChild('operation-a', description: 'description');
    final childB = sut.startChild('operation-b', description: 'description');
    final endTimestamp = getUtcDateTime();

    await sut.finish(endTimestamp: endTimestamp);
    await childA.finish();
    await childB.finish();

    expect(childA.endTimestamp, endTimestamp);
    expect(childB.endTimestamp, endTimestamp);
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

  test('tracer sets non-string data to extra', () async {
    final sut = fixture.getSut();

    sut.setData('test', {'key': 'value'});

    await sut.finish(status: SpanStatus.aborted());

    final tr = fixture.hub.captureTransactionCalls.first;

    expect(tr.extra?['test'], {'key': 'value'});
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

  test('tracer finishes after auto finish duration', () async {
    final sut = fixture.getSut(autoFinishAfter: Duration(milliseconds: 200));

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

  test('end trimmed to last child', () async {
    final sut = fixture.getSut(trimEnd: true);
    final endTimestamp = getUtcDateTime().add(Duration(minutes: 1));
    final olderEndTimeStamp = endTimestamp.add(Duration(seconds: 1));
    final oldestEndTimeStamp = olderEndTimeStamp.add(Duration(seconds: 1));

    final childA = sut.startChild('operation-a', description: 'description');
    final childB = sut.startChild('operation-b', description: 'description');

    await childA.finish(endTimestamp: endTimestamp);
    await childB.finish(endTimestamp: olderEndTimeStamp);
    await sut.finish(endTimestamp: oldestEndTimeStamp);

    expect(sut.endTimestamp, childB.endTimestamp);
  });

  test('end trimmed to child', () async {
    final sut = fixture.getSut(trimEnd: true);
    final endTimestamp = getUtcDateTime().add(Duration(minutes: 1));
    final olderEndTimeStamp = endTimestamp.add(Duration(seconds: 1));

    final childA = sut.startChild('operation-a', description: 'description');

    await childA.finish(endTimestamp: endTimestamp);
    await sut.finish(endTimestamp: olderEndTimeStamp);

    expect(sut.endTimestamp, childA.endTimestamp);
  });

  test('end not trimmed when no child', () async {
    final sut = fixture.getSut(trimEnd: true);
    final endTimestamp = getUtcDateTime();

    await sut.finish(endTimestamp: endTimestamp);

    expect(sut.endTimestamp, endTimestamp);
  });

  test('does not add more spans than configured in options', () async {
    fixture.hub.options.maxSpans = 2;
    final sut = fixture.getSut();

    sut.startChild('child1');
    sut.startChild('child2');
    sut.startChild('child3');

    expect(sut.children.length, 2);
  });

  test('when span limit is reached, startChild returns NoOpSpan', () async {
    fixture.hub.options.maxSpans = 2;
    final sut = fixture.getSut();

    sut.startChild('child1');
    sut.startChild('child2');

    expect(sut.startChild('child3'), isA<NoOpSentrySpan>());
  });
}

class Fixture {
  final hub = MockHub();

  SentryTracer getSut({
    bool? sampled = true,
    bool waitForChildren = false,
    bool trimEnd = false,
    Duration? autoFinishAfter,
  }) {
    final context = SentryTransactionContext(
      'name',
      'op',
      sampled: sampled,
    );
    return SentryTracer(
      context,
      hub,
      waitForChildren: waitForChildren,
      autoFinishAfter: autoFinishAfter,
      trimEnd: trimEnd,
    );
  }
}
