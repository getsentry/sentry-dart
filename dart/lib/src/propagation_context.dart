import 'package:meta/meta.dart';

import '../sentry.dart';

@internal
class PropagationContext {
  late SentryId traceId;
  late SpanId spanId;
  SentryBaggage? baggage;

  PropagationContext() {
    traceId = SentryId.newId();
    spanId = SpanId.newId();
  }

  SentryTraceHeader toSentryTrace() => SentryTraceHeader(traceId, spanId);
}
