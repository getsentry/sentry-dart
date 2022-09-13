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
    final tracesSamplingDecision =
        samplingContext.transactionContext.tracesSamplingDecision;
    if (tracesSamplingDecision != null) {
      return tracesSamplingDecision;
    }

    final tracesSampler = _options.tracesSampler;
    if (tracesSampler != null) {
      final result = tracesSampler(samplingContext);
      if (result != null) {
        return SentryTracesSamplingDecision(
          _sample(result),
          sampleRate: result,
        );
      }
    }

    final parentTracesSamplingDecision =
        samplingContext.transactionContext.parentTracesSamplingDecision;
    if (parentTracesSamplingDecision != null) {
      return parentTracesSamplingDecision;
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
