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
  });

  test('fromJson deserializes', () {
    final map = <String, dynamic>{
      'op': 'op',
      'span_id': '0000000000000000',
      'trace_id': '00000000000000000000000000000000',
      'parent_span_id': '0000000000000000',
      'description': 'desc',
      'status': 'aborted',
      'origin': 'auto.ui'
    };
    map.addAll(testUnknown);
    final traceContext = SentryTraceContext.fromJson(map);

    expect(traceContext.description, 'desc');
    expect(traceContext.operation, 'op');
    expect(traceContext.spanId.toString(), '0000000000000000');
    expect(traceContext.traceId.toString(), '00000000000000000000000000000000');
    expect(traceContext.parentSpanId.toString(), '0000000000000000');
    expect(traceContext.status.toString(), 'aborted');
    expect(traceContext.sampled, true);
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
      unknown: testUnknown,
    );
  }
}
