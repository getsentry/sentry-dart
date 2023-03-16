import 'dart:math';

import 'package:meta/meta.dart';

import '../sentry.dart';

@internal
class SentryTracesSampler {
  final SentryOptions _options;
  final Random _random;

  SentryTracesSampler(
    this._options, {
    Random? random,
  }) : _random = random ?? Random();

  SentryTracesSamplingDecision sample(SentrySamplingContext samplingContext) {
    final samplingDecision =
        samplingContext.transactionContext.samplingDecision;
    if (samplingDecision != null) {
      return samplingDecision;
    }

    final tracesSampler = _options.tracesSampler;
    if (tracesSampler != null) {
      try {
        final result = tracesSampler(samplingContext);
        if (result != null) {
          return SentryTracesSamplingDecision(
            _sample(result),
            sampleRate: result,
          );
        }
      } catch (exception, stackTrace) {
        _options.logger(
          SentryLevel.error,
          'The tracesSampler callback threw an exception',
          exception: exception,
          stackTrace: stackTrace,
        );
        if (_options.devMode) {
          rethrow;
        }
      }
    }

    final parentSamplingDecision =
        samplingContext.transactionContext.parentSamplingDecision;
    if (parentSamplingDecision != null) {
      return parentSamplingDecision;
    }

    final tracesSampleRate = _options.tracesSampleRate;
    if (tracesSampleRate != null) {
      return SentryTracesSamplingDecision(
        _sample(tracesSampleRate),
        sampleRate: tracesSampleRate,
      );
    }

    return SentryTracesSamplingDecision(false);
  }

  bool _sample(double result) => !(result < _random.nextDouble());
}
