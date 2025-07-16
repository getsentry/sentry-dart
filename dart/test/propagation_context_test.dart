import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry/src/transport/noop_transport.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

SentryOptions _createOptions() {
  final options = SentryOptions(dsn: 'https://public@sentry.example.com/1');
  // Disable transports – we don't want real network calls in unit tests.
  options.transport = NoOpTransport();
  // Ensure deterministic sampling decisions; we'll provide them manually.
  return options;
}

void main() {
  group('PropagationContext', () {
    group('sampleRand', () {
      test('is reused for transactions within the same trace', () {
        final options = defaultTestOptions()..tracesSampleRate = 1.0;
        final hub = Hub(options);

        final tx1 = hub.startTransaction('tx1', 'op') as SentryTracer;
        final rand1 = tx1.samplingDecision?.sampleRand;

        // Sanity check
        expect(rand1, isNotNull);

        final tx2 = hub.startTransaction('tx2', 'op') as SentryTracer;
        final rand2 = tx2.samplingDecision?.sampleRand;

        expect(rand2, equals(rand1));
      });

      test('is generated within a transaction in a new trace', () {
        final options = defaultTestOptions()..tracesSampleRate = 1.0;
        final hub = Hub(options);

        final tx1 = hub.startTransaction('tx1', 'op') as SentryTracer;
        final rand1 = tx1.samplingDecision?.sampleRand;
        expect(rand1, isNotNull);

        // Start a new trace
        hub.generateNewTrace();

        final tx2 = hub.startTransaction('tx2', 'op') as SentryTracer;
        final rand2 = tx2.samplingDecision?.sampleRand;

        expect(rand2, isNotNull);
        expect(rand2, isNot(equals(rand1)));
      });
    });

    group('sampled lifecycle', () {
      late Hub hub;

      setUp(() {
        final options = _createOptions();
        hub = Hub(options);
      });

      test('is null by default', () {
        expect(hub.scope.propagationContext.sampled, isNull);
      });

      test('is set by the first transaction and stays unchanged', () {
        // 1. Start the first (root) transaction with an explicit sampled = true.
        final txContextTrue = SentryTransactionContext(
          'trx',
          'op',
          samplingDecision: SentryTracesSamplingDecision(true),
        );
        hub.startTransactionWithContext(txContextTrue);

        expect(hub.scope.propagationContext.sampled, isTrue);

        // 2. Start a second transaction with sampled = false – the flag must not change.
        final txContextFalse = SentryTransactionContext(
          'trx-2',
          'op',
          samplingDecision: SentryTracesSamplingDecision(false),
        );
        hub.startTransactionWithContext(txContextFalse);

        expect(hub.scope.propagationContext.sampled, isTrue,
            reason: 'sampled flag must remain unchanged for the trace');
      });

      test('is reset when a new trace id is generated', () {
        final txContext = SentryTransactionContext(
          'trx',
          'op',
          samplingDecision: SentryTracesSamplingDecision(true),
        );
        hub.startTransactionWithContext(txContext);
        expect(hub.scope.propagationContext.sampled, isTrue);

        // Simulate new trace.
        hub.generateNewTraceId();
        expect(hub.scope.propagationContext.sampled, isNull);
      });

      test('sentry-trace header reflects sampled flag', () {
        final txContext = SentryTransactionContext(
          'trx',
          'op',
          samplingDecision: SentryTracesSamplingDecision(true),
        );
        hub.startTransactionWithContext(txContext);

        final header = hub.scope.propagationContext.toSentryTrace();
        expect(header.sampled, isTrue);
        expect(header.value.split('-').length, 3,
            reason: 'header must contain the sampled decision');
      });
    });
  });
}