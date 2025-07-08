import 'dart:math';

import 'package:meta/meta.dart';

import '../sentry.dart';

@internal
class SentryTracesSampler {
  SentryTracesSampler(this._hub) {
    _options = _hub.options;
    if (_options.tracesSampler != null && _options.tracesSampleRate != null) {
      _options.log(SentryLevel.warning,
          'Both tracesSampler and traceSampleRate are set. tracesSampler will take precedence and fallback to traceSampleRate if it returns null.');
    }
  }

  final Hub _hub;

  late final SentryOptions _options;

  SentryTracesSamplingDecision sample(SentrySamplingContext samplingContext) {
    final tracesSampleRand = _hub.scope.propagationContext.sampleRand;
    final samplingDecision =
        samplingContext.transactionContext.samplingDecision;
    if (samplingDecision != null) {
      return samplingDecision;
    }

    final tracesSampler = _options.tracesSampler;
    if (tracesSampler != null) {
      try {
        final sampleRate = tracesSampler(samplingContext);
        if (sampleRate != null) {
          return _makeTracesSamplingDecision(
              sampleRate: sampleRate, sampleRand: tracesSampleRand);
        }
      } catch (exception, stackTrace) {
        _options.log(
          SentryLevel.error,
          'The tracesSampler callback threw an exception',
          exception: exception,
          stackTrace: stackTrace,
        );
        if (_options.automatedTestMode) {
          rethrow;
        }
      }
    }

    final parentSamplingDecision =
        samplingContext.transactionContext.parentSamplingDecision;
    if (parentSamplingDecision != null) {
      return parentSamplingDecision;
    }

    double? optionsRate = _options.tracesSampleRate;
    if (optionsRate != null) {
      return _makeTracesSamplingDecision(
          sampleRate: optionsRate, sampleRand: tracesSampleRand);
    }

    return SentryTracesSamplingDecision(false);
  }

  bool sampleProfiling(SentryTracesSamplingDecision tracesSamplingDecision) {
    double? optionsRate = _options.profilesSampleRate;
    if (optionsRate == null || !tracesSamplingDecision.sampled) {
      return false;
    }
    return _isSampled(optionsRate);
  }

  SentryTracesSamplingDecision _makeTracesSamplingDecision(
      {required double sampleRate, required double sampleRand}) {
    final sampled = _isSampled(sampleRate, sampleRand: sampleRand);
    return SentryTracesSamplingDecision(sampled,
        sampleRate: sampleRate, sampleRand: sampleRand);
  }

  bool _isSampled(double sampleRate, {double? sampleRand}) {
    final rand = sampleRand ?? Random().nextDouble();
    return rand <= sampleRate;
  }
}
