import 'package:meta/meta.dart';

import '../sentry.dart';

@immutable
class SentrySpanContext {
  /// Determines which trace the Span belongs to
  late final SentryId traceId;

  /// Span id
  late final SpanId spanId;

  /// Id of a parent span
  final SpanId? parentSpanId;

  /// Short code identifying the type of operation the span is measuring
  final String operation;

  /// Longer description of the span's operation, which uniquely identifies the span but is
  /// consistent across instances of the span.
  final String? description;

  final String? origin;

  /// Item encoded as JSON
  Map<String, dynamic> toJson() {
    return {
      'span_id': spanId.toString(),
      'trace_id': traceId.toString(),
      'op': operation,
      if (parentSpanId != null) 'parent_span_id': parentSpanId.toString(),
      if (description != null) 'description': description,
      if (origin != null) 'origin': origin,
    };
  }

  SentrySpanContext({
    SentryId? traceId,
    SpanId? spanId,
    this.parentSpanId,
    required this.operation,
    this.description,
    this.origin,
  })  : traceId = traceId ?? SentryId.newId(),
        spanId = spanId ?? SpanId.newId();

  @internal
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
      origin: origin,
    );
  }
}
