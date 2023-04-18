import 'dart:math';

import 'package:meta/meta.dart';

import '../sentry.dart';

@internal
class SentryTracesSampler {

  static final defaultSampleRate = 1.0;

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

    double? tracesSampleRateFromOptions = _options.tracesSampleRate;
    bool? isEnableTracing = _options.enableTracing;
    double? defaultSampleRate = isEnableTracing == true ? SentryTracesSampler.defaultSampleRate : null;
    double? tracesSampleRateOrDefault = tracesSampleRateFromOptions ?? defaultSampleRate;

    if (tracesSampleRateOrDefault != null) {
      return SentryTracesSamplingDecision(
        _sample(tracesSampleRateOrDefault),
        sampleRate: tracesSampleRateOrDefault,
      );
    }

    return SentryTracesSamplingDecision(false);
  }

  bool _sample(double result) => !(result < _random.nextDouble());
}
