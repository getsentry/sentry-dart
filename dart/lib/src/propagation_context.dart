import 'package:meta/meta.dart';
import 'protocol.dart';
import 'sentry_baggage.dart';

@internal
class PropagationContext {
  late SentryId traceId = SentryId.newId();
  late SpanId spanId = SpanId.newId();
  SentryBaggage? baggage;

  SentryTraceHeader toSentryTrace() => SentryTraceHeader(traceId, spanId);
}
