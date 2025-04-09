import 'package:meta/meta.dart';

import '../../sentry.dart';

@internal
void addTracingHeadersToHttpHeader(Map<String, dynamic> headers,
    {ISentrySpan? span, Hub? hub}) {
  hub ??= Sentry.currentHub;

  if (span != null) {
    addSentryTraceHeaderFromSpan(span, headers);
    addBaggageHeaderFromSpan(
      span,
      headers,
      logger: hub.options.logger,
    );
  } else {
    final scope = hub.scope;
    final propagationContext = scope.propagationContext;

    final traceHeader = propagationContext.toSentryTrace();
    addSentryTraceHeader(traceHeader, headers);

    final baggage = propagationContext.baggage;
    if (baggage != null) {
      final baggageHeader = SentryBaggageHeader.fromBaggage(baggage);
      addBaggageHeader(baggageHeader, headers, logger: hub.options.logger);
    }
  }
}
