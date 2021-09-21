import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

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
  });

  test('toTraceContext gets sampled', () {
    final sut = fixture.getSut();

    final traceContext = sut.toTraceContext(sampled: true);

    expect(traceContext.sampled, true);
    expect(traceContext.spanId, isNotNull);
    expect(traceContext.traceId, isNotNull);
    expect(traceContext.operation, 'op');
    expect(traceContext.parentSpanId, isNotNull);
    expect(traceContext.description, 'desc');
  });
}

class Fixture {
  SentrySpanContext getSut() {
    return SentrySpanContext(
      operation: 'op',
      parentSpanId: SpanId.newId(),
      description: 'desc',
    );
  }
}
