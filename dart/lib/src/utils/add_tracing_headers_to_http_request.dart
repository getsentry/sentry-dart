import 'package:meta/meta.dart';

import '../../sentry.dart';
import '../propagation_context.dart';

@internal
void addTracingHeadersToHttpHeader(Map<String, dynamic> headers, Hub hub,
    {ISentrySpan? span}) {
  if (span != null) {
    addSentryTraceHeaderFromSpan(span, headers);
    addBaggageHeaderFromSpan(
      span,
      headers,
      log: hub.options.log,
    );
  } else {
    addSentryTraceHeaderFromScope(hub.scope, headers);
    addBaggageHeaderFromScope(hub.scope, headers, log: hub.options.log);
  }
}
