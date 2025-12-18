import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('PropagationContext', () {
    group('traceId', () {
      test('is a new trace id by default', () {
        final hub = Hub(defaultTestOptions());
        final sut = hub.scope.propagationContext;
        final traceId = sut.traceId;
        expect(traceId, isNotNull);
      });

      test('is reused for transactions within the same trace', () {
        final options = defaultTestOptions()..tracesSampleRate = 1.0;
        final hub = Hub(options);
        final sut = hub.scope.propagationContext;

        final tx1 = hub.startTransaction('tx1', 'op') as SentryTracer;
        final traceId1 = sut.traceId;

        final tx2 = hub.startTransaction('tx2', 'op') as SentryTracer;
        final traceId2 = sut.traceId;

        expect(tx1.context.traceId, equals(tx2.context.traceId));
        expect(tx1.context.traceId, equals(traceId1));
        expect(traceId1, equals(traceId2));
      });
    });

    group('sampleRand', () {
      test('is null by default', () {
        final hub = Hub(defaultTestOptions());
        final sut = hub.scope.propagationContext;
        final sampleRand = sut.sampleRand;
        expect(sampleRand, isNull);
      });

      test('is set by the first transaction and stays unchanged', () {
        final options = defaultTestOptions()..tracesSampleRate = 1.0;
        final hub = Hub(options);
        final sut = hub.scope.propagationContext;

        final tx1 = hub.startTransaction('tx1', 'op') as SentryTracer;
        final rand1 = tx1.samplingDecision?.sampleRand;
        expect(rand1, isNotNull);

        final tx2 = hub.startTransaction('tx2', 'op') as SentryTracer;
        final rand2 = tx2.samplingDecision?.sampleRand;

        expect(rand2, equals(rand1));
        expect(rand1, equals(sut.sampleRand));
      });
    });

    group('sampled', () {
      test('is null by default', () {
        final hub = Hub(defaultTestOptions()..tracesSampleRate = 1.0);
        final sut = hub.scope.propagationContext;
        expect(sut.sampled, isNull);
      });

      test('is set by the first transaction and stays unchanged', () {
        final hub = Hub(defaultTestOptions()..tracesSampleRate = 1.0);
        final sut = hub.scope.propagationContext;
        // 1. Start the first (root) transaction with an explicit sampled = true.
        final txContextTrue = SentryTransactionContext(
          'trx',
          'op',
          samplingDecision: SentryTracesSamplingDecision(true),
        );
        hub.startTransactionWithContext(txContextTrue);

        expect(sut.sampled, isTrue);

        // 2. Start a second transaction with sampled = false – the flag must not change.
        final txContextFalse = SentryTransactionContext(
          'trx-2',
          'op',
          samplingDecision: SentryTracesSamplingDecision(false),
        );
        hub.startTransactionWithContext(txContextFalse);

        expect(sut.sampled, isTrue,
            reason: 'sampled flag must remain unchanged for the trace');
      });

      test('is reset when a new trace is generated', () {
        final hub = Hub(defaultTestOptions()..tracesSampleRate = 1.0);
        final sut = hub.scope.propagationContext;
        final txContext = SentryTransactionContext(
          'trx',
          'op',
          samplingDecision: SentryTracesSamplingDecision(true),
        );
        hub.startTransactionWithContext(txContext);
        expect(sut.sampled, isTrue);

        // Simulate new trace.
        hub.generateNewTrace();
        expect(sut.sampled, isNull);
      });

      test('applySamplingDecision only sets sampled flag once', () {
        final hub = Hub(defaultTestOptions()..tracesSampleRate = 1.0);
        final sut = hub.scope.propagationContext;

        expect(sut.sampled, isNull);
        sut.applySamplingDecision(true);
        expect(sut.sampled, isTrue);
        sut.applySamplingDecision(false);
        expect(sut.sampled, isTrue);
      });
    });

    group('resetTrace', () {
      test('resets values', () {
        final hub = Hub(defaultTestOptions()..tracesSampleRate = 1.0);
        final sut = hub.scope.propagationContext;

        final traceId = SentryId.newId();
        sut.traceId = traceId;
        sut.sampleRand = 1.0;
        sut.applySamplingDecision(true);

        sut.resetTrace();

        expect(sut.traceId, isNot(traceId));
        expect(sut.sampleRand, isNull);
        expect(sut.sampled, isNull);
      });
    });

    group('toSentryTrace', () {
      test('header reflects values', () {
        final options = defaultTestOptions()..tracesSampleRate = 1.0;
        final hub = Hub(options);
        final sut = hub.scope.propagationContext;

        final txContext = SentryTransactionContext(
          'trx',
          'op',
          samplingDecision: SentryTracesSamplingDecision(true),
        );
        hub.startTransactionWithContext(txContext);

        final header = sut.toSentryTrace();
        expect(header.sampled, isTrue);
        expect(header.value.split('-').length, 3,
            reason: 'header must contain the sampled decision');
      });
    });

    group('getOrCreateTraceContextHeader', () {
      test('creates header with correct parameters', () {
        final hub = Hub(defaultTestOptions());
        final sut = hub.scope.propagationContext;

        final header = sut.getOrCreateTraceContextHeader(
          publicKey: 'test-public-key',
          segmentName: 'test-segment',
          release: '1.0.0',
          environment: 'production',
          tracesSampleRate: 0.5,
        );

        expect(header.traceId, sut.traceId);
        expect(header.publicKey, 'test-public-key');
        expect(header.transaction, 'test-segment');
        expect(header.release, '1.0.0');
        expect(header.environment, 'production');
        expect(header.sampleRate, '0.5');
      });

      test('returns cached header on subsequent calls', () {
        final hub = Hub(defaultTestOptions());
        final sut = hub.scope.propagationContext;

        final header1 = sut.getOrCreateTraceContextHeader(
          publicKey: 'key1',
          segmentName: 'segment1',
        );

        final header2 = sut.getOrCreateTraceContextHeader(
          publicKey: 'key2',
          segmentName: 'segment2',
        );

        expect(header1, same(header2));
        expect(header2.publicKey, 'key1');
        expect(header2.transaction, 'segment1');
      });

      test('includes sampleRand when set', () {
        final hub = Hub(defaultTestOptions());
        final sut = hub.scope.propagationContext;
        sut.sampleRand = 0.123456;

        final header = sut.getOrCreateTraceContextHeader(
          publicKey: 'key',
          segmentName: 'segment',
        );

        expect(header.sampleRand, '0.123456');
      });

      test('includes sampled when set', () {
        final hub = Hub(defaultTestOptions());
        final sut = hub.scope.propagationContext;
        sut.applySamplingDecision(true);

        final header = sut.getOrCreateTraceContextHeader(
          publicKey: 'key',
          segmentName: 'segment',
        );

        expect(header.sampled, 'true');
      });

      test('is reset when resetTrace is called', () {
        final hub = Hub(defaultTestOptions());
        final sut = hub.scope.propagationContext;

        final header1 = sut.getOrCreateTraceContextHeader(
          publicKey: 'key',
          segmentName: 'segment',
        );

        sut.resetTrace();

        final header2 = sut.getOrCreateTraceContextHeader(
          publicKey: 'key',
          segmentName: 'segment',
        );

        expect(header1, isNot(same(header2)));
        expect(header1.traceId, isNot(header2.traceId));
      });
    });
  });
}
