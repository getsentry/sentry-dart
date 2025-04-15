import 'package:meta/meta.dart';

import '../../sentry.dart';

@internal
void addTracingHeadersToHttpHeader(Map<String, dynamic> headers, Hub hub,
    {ISentrySpan? span}) {
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

    final baggageHeader = propagationContext.toBaggageHeader();
    if (baggageHeader != null) {
      addBaggageHeader(baggageHeader, headers, logger: hub.options.logger);
    }
  }
}
