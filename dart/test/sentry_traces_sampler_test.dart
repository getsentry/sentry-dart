import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_traces_sampler.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  final fixture = Fixture();

  test('transactionContext has sampled', () {
    final sut = fixture.getSut();

    final trContext = SentryTransactionContext(
      'name',
      'op',
      sampled: true,
    );
    final context = SentrySamplingContext(trContext, {});

    expect(sut.sample(context), true);
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

    expect(sut.sample(context), true);
  });

  test('transactionContext has parentSampled', () {
    final sut = fixture.getSut(tracesSampleRate: null);

    final trContext = SentryTransactionContext(
      'name',
      'op',
      parentSampled: true,
    );
    final context = SentrySamplingContext(trContext, {});

    expect(sut.sample(context), true);
  });

  test('options has rate 1.0', () {
    final sut = fixture.getSut();

    final trContext = SentryTransactionContext(
      'name',
      'op',
    );
    final context = SentrySamplingContext(trContext, {});

    expect(sut.sample(context), true);
  });

  test('options has rate 0.0', () {
    final sut = fixture.getSut(tracesSampleRate: 0.0);

    final trContext = SentryTransactionContext(
      'name',
      'op',
    );
    final context = SentrySamplingContext(trContext, {});

    expect(sut.sample(context), false);
  });
}

class Fixture {
  final options = SentryOptions(dsn: fakeDsn);

  SentryTracesSampler getSut({
    double? tracesSampleRate = 1.0,
    TracesSamplerCallback? tracesSampler,
  }) {
    options.tracesSampleRate = tracesSampleRate;
    options.tracesSampler = tracesSampler;
    return SentryTracesSampler(options);
  }
}
