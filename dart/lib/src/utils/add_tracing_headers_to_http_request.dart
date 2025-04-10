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

    final baggageHeader = propagationContext.toBaggageHeader();
    if (baggageHeader != null) {
      addBaggageHeader(baggageHeader, headers, logger: hub.options.logger);
    }
  }
}
