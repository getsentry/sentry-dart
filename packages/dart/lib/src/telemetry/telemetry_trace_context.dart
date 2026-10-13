import '../hub.dart';
import '../protocol.dart';
import 'span/sentry_trace_lifecycle.dart';

/// The trace and span a log or metric is correlated with.
typedef TelemetryTraceContext = ({SentryId traceId, SpanId? spanId});

typedef TelemetryTraceContextProvider = TelemetryTraceContext Function();

/// Resolves the [TelemetryTraceContext] for [hub].
///
/// In streaming mode this is the active span, which lives on the zone-forked
/// scope or the hub's idle span and is therefore not visible through
/// [Hub.scope]. In static mode it is the transaction bound to the scope.
/// Without a span, only the propagation context's trace is used.
TelemetryTraceContext resolveTelemetryTraceContext(Hub hub) {
  final scope = hub.scope;
  if (hub.options.traceLifecycle == SentryTraceLifecycle.stream) {
    final activeSpan = hub.getActiveSpan();
    return (
      traceId: activeSpan?.traceId ?? scope.propagationContext.traceId,
      spanId: activeSpan?.spanId,
    );
  }
  return (
    traceId: scope.propagationContext.traceId,
    spanId: scope.span?.context.spanId,
  );
}
