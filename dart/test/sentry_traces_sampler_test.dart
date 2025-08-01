import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_traces_sampler.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  late Fixture fixture;
  const _sampleRand = 1.0;

  setUp(() {
    fixture = Fixture();
  });

  test('transactionContext has sampled', () {
    final sut = fixture.getSut();

    final trContext = SentryTransactionContext(
      'name',
      'op',
      samplingDecision: SentryTracesSamplingDecision(true),
    );
    final context = SentrySamplingContext(trContext, {});

    expect(sut.sample(context, _sampleRand).sampled, true);
  });

  test('options has sampler', () {
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
    final context = SentrySamplingContext(trContext, {});

    expect(sut.sample(context, _sampleRand).sampled, true);
  });

  test('transactionContext has parentSampled', () {
    final sut = fixture.getSut(tracesSampleRate: null);

    final trContext = SentryTransactionContext(
      'name',
      'op',
      parentSamplingDecision: SentryTracesSamplingDecision(true),
    );
    final context = SentrySamplingContext(trContext, {});

    expect(sut.sample(context, _sampleRand).sampled, true);
  });

  test('options has rate 1.0', () {
    final sut = fixture.getSut();

    final trContext = SentryTransactionContext(
      'name',
      'op',
    );
    final context = SentrySamplingContext(trContext, {});

    expect(sut.sample(context, _sampleRand).sampled, true);
  });

  test('options has rate 0.0', () {
    final sut = fixture.getSut(tracesSampleRate: 0.0);

    final trContext = SentryTransactionContext(
      'name',
      'op',
    );
    final context = SentrySamplingContext(trContext, {});

    expect(sut.sample(context, _sampleRand).sampled, false);
  });

  test('does not sample if tracesSampleRate and tracesSampleRate are null', () {
    final sut = fixture.getSut(tracesSampleRate: null, tracesSampler: null);

    final trContext = SentryTransactionContext(
      'name',
      'op',
    );
    final context = SentrySamplingContext(trContext, {});
    final samplingDecision = sut.sample(context, _sampleRand);

    expect(samplingDecision.sampleRate, isNull);
    expect(samplingDecision.sampleRand, isNull);
    expect(samplingDecision.sampled, false);
  });

  test('tracesSampler exception is handled', () {
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
    final context = SentrySamplingContext(trContext, {});
    sut.sample(context, _sampleRand);

    expect(fixture.loggedException, exception);
    expect(fixture.loggedLevel, SentryLevel.error);
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
