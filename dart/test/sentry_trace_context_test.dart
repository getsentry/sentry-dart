import 'package:sentry/sentry.dart';
import 'package:sentry/src/propagation_context.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  final fixture = Fixture();

  test('toJson serializes', () {
    final sut = fixture.getSut();

    final map = sut.toJson();

    expect(map['span_id'], isNotNull);
    expect(map['trace_id'], isNotNull);
    expect(map['op'], 'op');
    expect(map['parent_span_id'], isNotNull);
    expect(map['description'], 'desc');
    expect(map['status'], 'aborted');
    expect(map['origin'], 'auto.ui');
    expect(map['replay_id'], isNotNull);
    expect(map['data'], {'key': 'value'});
  });

  test('fromJson deserializes', () {
    final map = <String, dynamic>{
      'op': 'op',
      'span_id': '0000000000000001',
      'trace_id': '00000000000000000000000000000002',
      'parent_span_id': '0000000000000003',
      'description': 'desc',
      'status': 'aborted',
      'origin': 'auto.ui',
      'replay_id': '00000000000000000000000000000004',
      'data': {'key': 'value'},
    };
    map.addAll(testUnknown);
    final traceContext = SentryTraceContext.fromJson(map);

    expect(traceContext.description, 'desc');
    expect(traceContext.operation, 'op');
    expect(traceContext.spanId.toString(), '0000000000000001');
    expect(traceContext.traceId.toString(), '00000000000000000000000000000002');
    expect(traceContext.parentSpanId.toString(), '0000000000000003');
    expect(traceContext.status.toString(), 'aborted');
    expect(traceContext.sampled, true);
    expect(
        traceContext.replayId.toString(), '00000000000000000000000000000004');
    expect(traceContext.data, {'key': 'value'});
  });

  test('fromPropagationContext creates valid SentryTraceContext', () {
    final propagationContext = PropagationContext();

    final traceContext1 =
        SentryTraceContext.fromPropagationContext(propagationContext);
    final traceContext2 =
        SentryTraceContext.fromPropagationContext(propagationContext);

    expect(traceContext1.traceId, propagationContext.traceId);
    expect(traceContext1.traceId, traceContext1.traceId);
    // the span id is always generated new when creating a trace context from scope
    expect(traceContext1.spanId, isNot(traceContext2.spanId));
  });
}

class Fixture {
  SentryTraceContext getSut() {
    return SentryTraceContext(
      operation: 'op',
      parentSpanId: SpanId.newId(),
      description: 'desc',
      sampled: true,
      status: SpanStatus.aborted(),
      origin: 'auto.ui',
      replayId: SentryId.newId(),
      data: {'key': 'value'},
      unknown: testUnknown,
    );
  }
}
