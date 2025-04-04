import 'package:meta/meta.dart';

import '../sentry.dart';

class SentrySpanContext {
  /// Determines which trace the Span belongs to
  late SentryId traceId;

  /// Span id
  late SpanId spanId;

  /// Id of a parent span
  SpanId? parentSpanId;

  /// Short code identifying the type of operation the span is measuring
  String operation;

  /// Longer description of the span's operation, which uniquely identifies the span but is
  /// consistent across instances of the span.
  String? description;

  /// The origin of the span indicates what created the span.
  ///
  /// Gets set by the SDK. It is not expected to be set manually by users.
  ///
  /// See https://develop.sentry.dev/sdk/performance/trace-origin
  String? origin;

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
    Map<String, dynamic>? data,
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
      data: data,
    );
  }
}
