import '../../sentry.dart';

void addSentryTraceHeader(ISentrySpan span, Map<String, dynamic> headers) {
  final traceHeader = span.toSentryTrace();
  headers[traceHeader.name] = traceHeader.value;
}

void addBaggageHeader(ISentrySpan span, Map<String, dynamic> headers) {
  final baggage = span.toBaggageHeader();
  if (baggage != null) {
    // TODO: append if header already exist
    // overwrite if the key already exists
    // https://develop.sentry.dev/sdk/performance/dynamic-sampling-context/#baggage
    headers[baggage.name] = baggage.value;
  }
}

bool containsTracePropagationTarget(
    List<String> tracePropagationTargets, String url) {
  if (tracePropagationTargets.isEmpty) {
    return true;
  }
  for (final target in tracePropagationTargets) {
    // TODO: validate regex
    if (url.contains(target) || url.allMatches(target).isNotEmpty) {
      return true;
    }
  }
  return false;
}
