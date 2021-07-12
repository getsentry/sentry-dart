import 'dart:async';
import '../protocol.dart';

abstract class SpanInterface {
  DateTime get start;
  DateTime? end;
  SentrySpanContext get context;

  FutureOr<void> finish({
    SpanStatus? status,
    DateTime? end,
  });
}

mixin SpanMixin on SpanInterface {
  SentryTraceHeader toSentryTrace() {
    return SentryTraceHeader(
      context.traceId,
      context.spanId,
      context.isSampled,
    );
  }

  bool get finished => end != null;
}
