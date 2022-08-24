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

  bool sample(SentrySamplingContext samplingContext, double? tracesSampleRate) {
    final sampled = samplingContext.transactionContext.sampled;
    if (sampled != null) {
      return sampled;
    }

    final tracesSampler = _options.tracesSampler;
    if (tracesSampler != null) {
      final result = tracesSampler(samplingContext);
      if (result != null) {
        return _sample(result);
      }
    }

    final parentSampled = samplingContext.transactionContext.parentSampled;
    if (parentSampled != null) {
      return parentSampled;
    }

    if (tracesSampleRate != null) {
      return _sample(tracesSampleRate);
    }

    return false;
  }

  bool _sample(double result) => !(result < _random.nextDouble());
}
