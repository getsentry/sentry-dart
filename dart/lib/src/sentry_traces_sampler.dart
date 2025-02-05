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
  }) : _random = random ?? Random() {
    if (_options.tracesSampler != null && _options.tracesSampleRate != null) {
      _options.logger(SentryLevel.warning,
          'Both tracesSampler and traceSampleRate are set. tracesSampler will take precedence and fallback to traceSampleRate if it returns null.');
    }
  }

  SentryTracesSamplingDecision sample(SentrySamplingContext samplingContext) {
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
          return _makeSampleDecision(sampleRate);
        }
      } catch (exception, stackTrace) {
        _options.logger(
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
    double? defaultRate =
        // ignore: deprecated_member_use_from_same_package
        _options.enableTracing == true ? _defaultSampleRate : null;
    double? optionsOrDefaultRate = optionsRate ?? defaultRate;

    if (optionsOrDefaultRate != null) {
      return _makeSampleDecision(optionsOrDefaultRate);
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

  SentryTracesSamplingDecision _makeSampleDecision(double sampleRate) {
    final sampleRand = _random.nextDouble();
    final sampled = _isSampled(sampleRate, sampleRand: sampleRand);
    return SentryTracesSamplingDecision(sampled,
        sampleRate: sampleRate, sampleRand: sampleRand);
  }

  bool _isSampled(double sampleRate, {double? sampleRand}) {
    final rand = sampleRand ?? _random.nextDouble();
    return rand <= sampleRate;
  }
}
