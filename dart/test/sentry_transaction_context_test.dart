import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  final _traceId = SentryId.newId();
  final _spanId = SpanId.newId();

  SentryTransactionContext getSentryTransactionContext({
    bool? sampled,
    SentryTransactionNameSource? transactionNameSource,
    SentryBaggage? baggage,
  }) {
    final header = SentryTraceHeader(_traceId, _spanId, sampled: sampled);
    return SentryTransactionContext.fromSentryTrace(
      'name',
      'operation',
      header,
      transactionNameSource: transactionNameSource,
      baggage: baggage,
    );
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

    expect(context.parentSamplingDecision?.sampled, true);
  });

  test('transactionNameSource is custom by default', () {
    final context = getSentryTransactionContext(sampled: true);

    expect(context.transactionNameSource, SentryTransactionNameSource.custom);
  });

  test('transactionNameSource sets the given value', () {
    final context = getSentryTransactionContext(
      sampled: true,
      transactionNameSource: SentryTransactionNameSource.component,
    );

    expect(
        context.transactionNameSource, SentryTransactionNameSource.component);
  });

  test('sets sample rate if baggage is given', () {
    final baggage = SentryBaggage({});
    final id = SentryId.newId().toString();
    baggage.setTraceId(id);
    baggage.setPublicKey('publicKey');
    baggage.setSampleRate('1.0');
    final context = getSentryTransactionContext(
      sampled: true,
      baggage: baggage,
    );

    expect(context.parentSamplingDecision?.sampleRate, 1.0);
  });
}
