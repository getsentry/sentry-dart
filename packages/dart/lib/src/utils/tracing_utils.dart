import '../../sentry.dart';

SentryTraceHeader generateSentryTraceHeader(
    {SentryId? traceId, SpanId? spanId, bool? sampled}) {
  traceId ??= SentryId.newId();
  spanId ??= SpanId.newId();
  return SentryTraceHeader(traceId, spanId, sampled: sampled);
}

void addTracingHeadersToHttpHeader(
  Map<String, dynamic> headers,
  Hub hub, {
  InstrumentationSpan? span,
}) {
  if (span != null) {
    if (hub.options.propagateTraceparent) {
      addW3CHeaderFromSpan(span, headers);
    }
    addSentryTraceHeaderFromSpan(span, headers);
    addBaggageHeaderFromSpan(
      span,
      headers,
    );
  } else {
    if (hub.options.propagateTraceparent) {
      addW3CHeaderFromScope(hub.scope, headers);
    }
    addSentryTraceHeaderFromScope(hub.scope, headers);
    addBaggageHeaderFromScope(hub.scope, headers);
  }
}

void addSentryTraceHeaderFromScope(Scope scope, Map<String, dynamic> headers) {
  final propagationContext = scope.propagationContext;
  final traceHeader = propagationContext.toSentryTrace();
  headers[traceHeader.name] = traceHeader.value;
}

void addSentryTraceHeaderFromSpan(
    InstrumentationSpan span, Map<String, dynamic> headers) {
  final traceHeader = span.toSentryTrace();
  headers[traceHeader.name] = traceHeader.value;
}

void addSentryTraceHeader(
    SentryTraceHeader traceHeader, Map<String, dynamic> headers) {
  headers[traceHeader.name] = traceHeader.value;
}

void addW3CHeaderFromSpan(
    InstrumentationSpan span, Map<String, dynamic> headers) {
  final traceHeader = span.toSentryTrace();
  _addW3CHeaderFromSentryTrace(traceHeader, headers);
}

void addW3CHeaderFromScope(Scope scope, Map<String, dynamic> headers) {
  final propagationContext = scope.propagationContext;
  final traceHeader = propagationContext.toSentryTrace();
  _addW3CHeaderFromSentryTrace(traceHeader, headers);
}

void _addW3CHeaderFromSentryTrace(
    SentryTraceHeader traceHeader, Map<String, dynamic> headers) {
  headers['traceparent'] = formatAsW3CHeader(traceHeader);
}

String formatAsW3CHeader(SentryTraceHeader traceHeader) {
  final sampled = traceHeader.sampled;
  final sampledBit = sampled != null && sampled ? '01' : '00';
  return '00-${traceHeader.traceId}-${traceHeader.spanId}-$sampledBit';
}

void addBaggageHeaderFromScope(Scope scope, Map<String, dynamic> headers) {
  final baggageHeader = scope.propagationContext.toBaggageHeader();
  if (baggageHeader != null) {
    addBaggageHeader(baggageHeader, headers);
  }
}

void addBaggageHeaderFromSpan(
    InstrumentationSpan span, Map<String, dynamic> headers) {
  final baggage = span.toBaggageHeader();
  if (baggage != null) {
    addBaggageHeader(baggage, headers);
  }
}

void addBaggageHeader(
    SentryBaggageHeader baggage, Map<String, dynamic> headers) {
  final currentValue = headers[baggage.name] as String? ?? '';

  final currentBaggage = SentryBaggage.fromHeader(
    currentValue,
  );
  final sentryBaggage = SentryBaggage.fromHeader(
    baggage.value,
  );

  // overwrite sentry's keys https://develop.sentry.dev/sdk/performance/dynamic-sampling-context/#baggage
  final filteredBaggageHeader = Map.from(currentBaggage.keyValues);
  filteredBaggageHeader.removeWhere((key, value) => key.startsWith('sentry-'));

  final mergedBaggage = <String, String>{
    ...filteredBaggageHeader,
    ...sentryBaggage.keyValues,
  };

  final newBaggage = SentryBaggage(mergedBaggage);

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
