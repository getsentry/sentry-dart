import 'dart:math';

import '../sentry.dart';
import 'tracing.dart';

class SentryTracesSampler {
  SentryOptions _options;
  Random? _random;

  SentryTracesSampler(
    this._options, {
    Random? random,
  }) {
    _random = random ?? Random();
  }

  bool sample(SentrySamplingContext samplingContext) {
    // implement correct
    final tracesSampler = _options.tracesSampler;
    if (tracesSampler != null) {
      tracesSampler(samplingContext);
    }
    return true;
  }
}
