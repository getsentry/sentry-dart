import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/span/sentry_span_sampling_context.dart';
import 'package:test/test.dart';

void main() {
  group('SentrySamplingContext', () {
    group('when created for SpanV2', () {
      test('sets streaming lifecycle', () {
        final spanContext = SentrySpanSamplingContextV2(
            'span-name', {'key': SentryAttribute.string('value')});

        final context = SentrySamplingContext.forSpanV2(spanContext);

        expect(context.traceLifecycle, equals(SentryTraceLifecycle.streaming));
      });

      test('provides access to span context', () {
        final spanContext = SentrySpanSamplingContextV2('my-span', {});

        final context = SentrySamplingContext.forSpanV2(spanContext);

        expect(context.spanContext.name, equals('my-span'));
      });

      test('throws StateError when accessing transactionContext', () {
        final spanContext = SentrySpanSamplingContextV2('span', {});
        final context = SentrySamplingContext.forSpanV2(spanContext);

        expect(() => context.transactionContext, throwsA(isA<StateError>()));
      });

      test('returns empty customSamplingContext by default', () {
        final spanContext = SentrySpanSamplingContextV2('span', {});

        final context = SentrySamplingContext.forSpanV2(spanContext);

        expect(context.customSamplingContext, isEmpty);
      });
    });

    group('when created for transaction', () {
      test('sets static lifecycle', () {
        final transactionContext = SentryTransactionContext('tx-name', 'op');

        final context =
            SentrySamplingContext.forTransaction(transactionContext);

        expect(context.traceLifecycle, equals(SentryTraceLifecycle.static));
      });

      test('provides access to transaction context', () {
        final transactionContext =
            SentryTransactionContext('my-transaction', 'http');

        final context =
            SentrySamplingContext.forTransaction(transactionContext);

        expect(context.transactionContext.name, equals('my-transaction'));
        expect(context.transactionContext.operation, equals('http'));
      });

      test('throws StateError when accessing spanContext', () {
        final transactionContext = SentryTransactionContext('tx', 'op');
        final context =
            SentrySamplingContext.forTransaction(transactionContext);

        expect(() => context.spanContext, throwsA(isA<StateError>()));
      });

      test('preserves customSamplingContext', () {
        final transactionContext = SentryTransactionContext('tx', 'op');
        final customContext = {'userId': '123', 'premium': true};

        final context = SentrySamplingContext.forTransaction(
          transactionContext,
          customSamplingContext: customContext,
        );

        expect(context.customSamplingContext, equals(customContext));
      });

      test('returns unmodifiable customSamplingContext', () {
        final transactionContext = SentryTransactionContext('tx', 'op');
        final customContext = {'key': 'value'};

        final context = SentrySamplingContext.forTransaction(
          transactionContext,
          customSamplingContext: customContext,
        );

        expect(() => context.customSamplingContext['newKey'] = 'newValue',
            throwsA(isA<UnsupportedError>()));
      });
    });
  });

  group('SentrySpanSamplingContextV2', () {
    test('stores name and attributes', () {
      final attributes = {
        'key1': SentryAttribute.string('value1'),
        'key2': SentryAttribute.int(42),
      };

      final context = SentrySpanSamplingContextV2('my-span', attributes);

      expect(context.name, equals('my-span'));
      expect(context.attributes, equals(attributes));
    });
  });
}
