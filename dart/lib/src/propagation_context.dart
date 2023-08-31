import 'package:meta/meta.dart';

import '../sentry.dart';

@internal
class PropagationContext {
  late SentryId traceId;
  late SpanId spanId;
  SpanId? parentSpanId;
  bool? sampled;
  SentryBaggage? baggage;

  PropagationContext() {
    traceId = SentryId.newId();
    spanId = SpanId.newId();
  }
}
