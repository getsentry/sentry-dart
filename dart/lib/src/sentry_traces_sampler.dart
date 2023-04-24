import 'dart:math';

import 'package:meta/meta.dart';

import '../sentry.dart';

@internal
class SentryTracesSampler {
  static const _defaultSampleRate = 1.0;

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

    // final parentSamplingDecision =
    //     samplingContext.transactionContext.parentSamplingDecision;
    // if (parentSamplingDecision != null) {
    //   return parentSamplingDecision;
    // }

    double? optionsRate = _options.tracesSampleRate;
    double? defaultRate =
        _options.enableTracing == true ? _defaultSampleRate : null;
    double? optionsOrDefaultRate = optionsRate ?? defaultRate;

    if (optionsOrDefaultRate != null) {
      return SentryTracesSamplingDecision(
        _sample(optionsOrDefaultRate),
        sampleRate: optionsOrDefaultRate,
      );
    }

    return SentryTracesSamplingDecision(false);
  }

  bool _sample(double result) => !(result < _random.nextDouble());
}
