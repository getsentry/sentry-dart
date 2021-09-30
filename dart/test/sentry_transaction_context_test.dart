import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  final _traceId = SentryId.newId();
  final _spanId = SpanId.newId();

  SentryTransactionContext getSentryTransactionContext({bool? sampled}) {
    final header = SentryTraceHeader(_traceId, _spanId, sampled: sampled);
    return SentryTransactionContext.fromSentryTrace(
        'name', 'operation', header);
  }

  test('parent span id is set from header', () {
    final context = getSentryTransactionContext();

    expect(context.parentSpanId, _spanId);
  });

  test('trace id is set from header', () {
    final context = getSentryTransactionContext();

    expect(context.traceId, _traceId);
  });

  test('parent sampled is set from header', () {
    final context = getSentryTransactionContext(sampled: true);

    expect(context.parentSampled, true);
  });
}
