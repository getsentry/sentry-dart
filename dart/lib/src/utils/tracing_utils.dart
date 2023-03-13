import '../../sentry.dart';
import '../sentry_baggage.dart';

void addSentryTraceHeader(ISentrySpan span, Map<String, dynamic> headers) {
  final traceHeader = span.toSentryTrace();
  headers[traceHeader.name] = traceHeader.value;
}

void addBaggageHeader(
  ISentrySpan span,
  Map<String, dynamic> headers, {
  SentryLogger? logger,
}) {
  final baggage = span.toBaggageHeader();
  if (baggage != null) {
    final currentValue = headers[baggage.name] as String? ?? '';

    final currentBaggage = SentryBaggage.fromHeader(
      currentValue,
      logger: logger,
    );
    final sentryBaggage = SentryBaggage.fromHeader(
      baggage.value,
      logger: logger,
    );

    // overwrite sentry's keys https://develop.sentry.dev/sdk/performance/dynamic-sampling-context/#baggage
    final filteredBaggageHeader = Map.from(currentBaggage.keyValues);
    filteredBaggageHeader
        .removeWhere((key, value) => key.startsWith('sentry-'));

    final mergedBaggage = <String, String>{
      ...filteredBaggageHeader,
      ...sentryBaggage.keyValues,
    };

    final newBaggage = SentryBaggage(mergedBaggage, logger: logger);

    headers[baggage.name] = newBaggage.toHeaderString();
  }
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
