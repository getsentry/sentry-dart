import 'package:meta/meta.dart';

import '../sentry.dart';

@immutable
class SentrySpanContext {
  late final SentryId traceId;
  late final SpanId spanId;
  final SpanId? parentSpanId;
  final String operation;
  final String? description;

  /// Item header encoded as JSON
  Map<String, dynamic> toJson() {
    return {
      'span_id': spanId.toString(),
      'trace_id': traceId.toString(),
      'op': operation,
      if (parentSpanId != null) 'parent_span_id': parentSpanId.toString(),
      if (description != null) 'description': description,
    };
  }

  SentrySpanContext({
    SentryId? traceId,
    SpanId? spanId,
    this.parentSpanId,
    required this.operation,
    this.description,
  })  : traceId = traceId ?? SentryId.newId(),
        spanId = spanId ?? SpanId.newId();

  SentryTraceContext toTraceContext({
    bool? sampled,
    SpanStatus? status,
  }) {
    return SentryTraceContext(
      operation: operation,
      traceId: traceId,
      spanId: spanId,
      description: description,
      parentSpanId: parentSpanId,
      sampled: sampled,
      status: status,
    );
  }
}
