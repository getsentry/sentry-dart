import '../../sentry.dart';

void addSentryTraceHeaderFromSpan(
    ISentrySpan span, Map<String, dynamic> headers) {
  final traceHeader = span.toSentryTrace();
  headers[traceHeader.name] = traceHeader.value;
}

void addSentryTraceHeader(
    SentryTraceHeader traceHeader, Map<String, dynamic> headers) {
  headers[traceHeader.name] = traceHeader.value;
}

void addBaggageHeaderFromSpan(
  ISentrySpan span,
  Map<String, dynamic> headers, {
  SdkLogCallback? log,
}) {
  final baggage = span.toBaggageHeader();
  if (baggage != null) {
    addBaggageHeader(baggage, headers, log: log);
  }
}

void addBaggageHeader(
  SentryBaggageHeader baggage,
  Map<String, dynamic> headers, {
  SdkLogCallback? log,
}) {
  final currentValue = headers[baggage.name] as String? ?? '';

  final currentBaggage = SentryBaggage.fromHeader(
    currentValue,
    log: log,
  );
  final sentryBaggage = SentryBaggage.fromHeader(
    baggage.value,
    log: log,
  );

  // overwrite sentry's keys https://develop.sentry.dev/sdk/performance/dynamic-sampling-context/#baggage
  final filteredBaggageHeader = Map.from(currentBaggage.keyValues);
  filteredBaggageHeader.removeWhere((key, value) => key.startsWith('sentry-'));

  final mergedBaggage = <String, String>{
    ...filteredBaggageHeader,
    ...sentryBaggage.keyValues,
  };

  final newBaggage = SentryBaggage(mergedBaggage, log: log);

  headers[baggage.name] = newBaggage.toHeaderString();
}

bool containsTargetOrMatchesRegExp(
    List<String> tracePropagationTargets, String url) {
  if (tracePropagationTargets.isEmpty) {
    return false;
  }
  for (final target in tracePropagationTargets) {
    if (url.contains(target)) {
      return true;
    }
    try {
      final regExp = RegExp(target, caseSensitive: false);
      if (regExp.hasMatch(url)) {
        return true;
      }
    } on FormatException {
      // ignore invalid regex
      continue;
    }
  }
  return false;
}

bool isValidSampleRate(double? sampleRate) {
  if (sampleRate == null) {
    return false;
  }
  return !sampleRate.isNaN && sampleRate >= 0.0 && sampleRate <= 1.0;
}

bool isValidSampleRand(double? sampleRand) {
  if (sampleRand == null) {
    return false;
  }
  return !sampleRand.isNaN && sampleRand >= 0.0 && sampleRand < 1.0;
}
