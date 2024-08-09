import 'package:sentry/sentry.dart';
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
      'replay_id': '00000000000000000000000000000004'
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
      unknown: testUnknown,
    );
  }
}
