import '../../sentry.dart';

void addSentryTraceHeader(ISentrySpan span, Map<String, dynamic> headers) {
  final traceHeader = span.toSentryTrace();
  headers[traceHeader.name] = traceHeader.value;
}

void addBaggageHeader(ISentrySpan span, Map<String, dynamic> headers) {
  final baggage = span.toBaggageHeader();
  if (baggage != null) {
    // TODO: overwrite if the sentry key already exists
    // https://develop.sentry.dev/sdk/performance/dynamic-sampling-context/#baggage
    var currentValue = headers[baggage.name] as String? ?? '';

    if (currentValue.isNotEmpty == true) {
      currentValue = '$currentValue,';
    }
    currentValue = '$currentValue${baggage.value}';

    headers[baggage.name] = currentValue;
  }
}

bool containsTracePropagationTarget(
    List<String> tracePropagationTargets, String url) {
  if (tracePropagationTargets.isEmpty) {
    return true;
  }
  for (final target in tracePropagationTargets) {
    final regExp = RegExp(target, caseSensitive: false);
    if (url.contains(target) || regExp.hasMatch(url)) {
      return true;
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
