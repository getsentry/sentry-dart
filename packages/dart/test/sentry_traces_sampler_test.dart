import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_traces_sampler.dart';
import 'package:sentry/src/telemetry/span/sentry_span_sampling_context.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  late Fixture fixture;
  const _sampleRand = 1.0;

  setUp(() {
    fixture = Fixture();
  });

  group('SentryTracesSampler', () {
    group('when sampling SpanV2', () {
      test('samples with tracesSampleRate 1.0', () {
        final sut = fixture.getSut(tracesSampleRate: 1.0);
        final spanContext = SentrySpanSamplingContextV2('span-name', {});
        final context = SentrySamplingContext.forSpanV2(spanContext);

        final decision = sut.sample(context, _sampleRand);

        expect(decision.sampled, isTrue);
        expect(decision.sampleRate, equals(1.0));
      });

      test('does not sample with tracesSampleRate 0.0', () {
        final sut = fixture.getSut(tracesSampleRate: 0.0);
        final spanContext = SentrySpanSamplingContextV2('span-name', {});
        final context = SentrySamplingContext.forSpanV2(spanContext);

        final decision = sut.sample(context, _sampleRand);

        expect(decision.sampled, isFalse);
        expect(decision.sampleRate, equals(0.0));
      });

      test('uses tracesSampler callback when provided', () {
        double? sampler(SentrySamplingContext samplingContext) {
          expect(samplingContext.traceLifecycle,
              equals(SentryTraceLifecycle.streaming));
          return 1.0;
        }

        final sut =
            fixture.getSut(tracesSampleRate: null, tracesSampler: sampler);
        final spanContext = SentrySpanSamplingContextV2('test-span', {});
        final context = SentrySamplingContext.forSpanV2(spanContext);

        final decision = sut.sample(context, _sampleRand);

        expect(decision.sampled, isTrue);
      });

      test('does not sample when tracing is disabled', () {
        final sut = fixture.getSut(tracesSampleRate: null, tracesSampler: null);
        final spanContext = SentrySpanSamplingContextV2('span-name', {});
        final context = SentrySamplingContext.forSpanV2(spanContext);

        final decision = sut.sample(context, _sampleRand);

        expect(decision.sampled, isFalse);
        expect(decision.sampleRate, isNull);
        expect(decision.sampleRand, isNull);
      });

      test('preserves sampleRand in decision', () {
        final sut = fixture.getSut(tracesSampleRate: 1.0);
        final spanContext = SentrySpanSamplingContextV2('span-name', {});
        final context = SentrySamplingContext.forSpanV2(spanContext);
        const expectedSampleRand = 0.42;

        final decision = sut.sample(context, expectedSampleRand);

        expect(decision.sampleRand, equals(expectedSampleRand));
      });
    });

    group('when sampling transaction', () {
      test('samples when transactionContext has sampled', () {
        final sut = fixture.getSut();

        final trContext = SentryTransactionContext(
          'name',
          'op',
          samplingDecision: SentryTracesSamplingDecision(true),
        );
        final context = SentrySamplingContext.forTransaction(trContext);

        expect(sut.sample(context, _sampleRand).sampled, true);
      });

      test('uses tracesSampler callback when provided', () {
        double? sampler(SentrySamplingContext samplingContext) {
          return 1.0;
        }

        final sut = fixture.getSut(
          tracesSampleRate: null,
          tracesSampler: sampler,
        );

        final trContext = SentryTransactionContext(
          'name',
          'op',
        );
        final context = SentrySamplingContext.forTransaction(trContext);

        expect(sut.sample(context, _sampleRand).sampled, true);
      });

      test('samples when transactionContext has parentSampled', () {
        final sut = fixture.getSut(tracesSampleRate: null);

        final trContext = SentryTransactionContext(
          'name',
          'op',
          parentSamplingDecision: SentryTracesSamplingDecision(true),
        );
        final context = SentrySamplingContext.forTransaction(trContext);

        expect(sut.sample(context, _sampleRand).sampled, true);
      });

      test('samples with tracesSampleRate 1.0', () {
        final sut = fixture.getSut();

        final trContext = SentryTransactionContext(
          'name',
          'op',
        );
        final context = SentrySamplingContext.forTransaction(trContext);

        expect(sut.sample(context, _sampleRand).sampled, true);
      });

      test('does not sample with tracesSampleRate 0.0', () {
        final sut = fixture.getSut(tracesSampleRate: 0.0);

        final trContext = SentryTransactionContext(
          'name',
          'op',
        );
        final context = SentrySamplingContext.forTransaction(trContext);

        expect(sut.sample(context, _sampleRand).sampled, false);
      });

      test('does not sample when tracing is disabled', () {
        final sut = fixture.getSut(tracesSampleRate: null, tracesSampler: null);

        final trContext = SentryTransactionContext(
          'name',
          'op',
        );
        final context = SentrySamplingContext.forTransaction(trContext);
        final samplingDecision = sut.sample(context, _sampleRand);

        expect(samplingDecision.sampleRate, isNull);
        expect(samplingDecision.sampleRand, isNull);
        expect(samplingDecision.sampled, false);
      });

      test('handles tracesSampler exception gracefully', () {
        fixture.options.automatedTestMode = false;
        final sut = fixture.getSut(debug: true);

        final exception = Exception("tracesSampler exception");
        double? sampler(SentrySamplingContext samplingContext) {
          throw exception;
        }

        fixture.options.tracesSampler = sampler;

        final trContext = SentryTransactionContext(
          'name',
          'op',
        );
        final context = SentrySamplingContext.forTransaction(trContext);
        sut.sample(context, _sampleRand);

        expect(fixture.loggedException, exception);
        expect(fixture.loggedLevel, SentryLevel.error);
      });
    });
  });
}

class Fixture {
  final options = defaultTestOptions();

  SentryLevel? loggedLevel;
  Object? loggedException;

  SentryTracesSampler getSut({
    double? tracesSampleRate = 1.0,
    TracesSamplerCallback? tracesSampler,
    bool debug = false,
  }) {
    options.tracesSampleRate = tracesSampleRate;
    options.tracesSampler = tracesSampler;
    options.debug = debug;
    options.log = mockLogger;
    return SentryTracesSampler(options);
  }

  void mockLogger(
    SentryLevel level,
    String message, {
    String? logger,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    loggedLevel = level;
    loggedException = exception;
  }
}
