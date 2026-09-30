import '../hub.dart';
import '../protocol.dart';

/// The trace and span a log or metric is correlated with.
typedef TelemetryTraceContext = ({SentryId traceId, SpanId? spanId});

typedef TelemetryTraceContextProvider = TelemetryTraceContext Function();

/// Resolves the [TelemetryTraceContext] for [hub].
///
/// Prefers the active streaming span, which lives on the zone-forked scope or
/// the hub's idle span and is therefore not visible through [Hub.scope].
/// Falls back to the scope's transaction span and propagation context.
TelemetryTraceContext resolveTelemetryTraceContext(Hub hub) {
  final activeSpan = hub.getActiveSpan();
  if (activeSpan != null) {
    return (traceId: activeSpan.traceId, spanId: activeSpan.spanId);
  }
  final scope = hub.scope;
  return (
    traceId: scope.propagationContext.traceId,
    spanId: scope.span?.context.spanId,
  );
}
