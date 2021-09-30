import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  final _traceId = SentryId.newId();
  final _spanId = SpanId.newId();
  test('header adds 1 to sampled', () {
    final header = SentryTraceHeader(_traceId, _spanId, sampled: true);

    expect(header.value, '$_traceId-$_spanId-1');
  });

  test('header adds 0 to not sampled', () {
    final header = SentryTraceHeader(_traceId, _spanId, sampled: false);

    expect(header.value, '$_traceId-$_spanId-0');
  });

  test('header does not add sampled if no sampled decision', () {
    final header = SentryTraceHeader(_traceId, _spanId);

    expect(header.value, '$_traceId-$_spanId');
  });

  test('header return its name', () {
    final header = SentryTraceHeader(_traceId, _spanId);

    expect(header.name, 'sentry-trace');
  });

  test('invalid header throws $InvalidSentryTraceHeaderException', () {
    var exception;
    try {
      SentryTraceHeader.fromTraceHeader('invalidHeader');
    } catch (error) {
      exception = error;
    }

    expect(exception is InvalidSentryTraceHeaderException, true);
  });
}
