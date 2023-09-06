import 'package:meta/meta.dart';

import '../sentry.dart';

@internal
class PropagationContext {
  late SentryId traceId = SentryId.newId();
  late SpanId spanId = SpanId.newId();
  SentryBaggage? baggage;

  SentryTraceHeader toSentryTrace() => SentryTraceHeader(traceId, spanId);
}
