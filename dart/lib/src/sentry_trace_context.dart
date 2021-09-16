import 'package:meta/meta.dart';

import 'protocol.dart';

@immutable
class SentryTraceContext {
  static const String type = 'trace';

  late final SentryId traceId;
  late final SpanId spanId;
  final SpanId? parentSpanId;
  final bool? sampled;
  final String operation;
  final String? description;
  final SpanStatus? status;

  factory SentryTraceContext.fromJson(Map<String, dynamic> json) {
    return SentryTraceContext(
      operation: json['op'] as String,
      spanId: SpanId.fromId(json['span_id'] as String),
      parentSpanId: json['parent_span_id'] == null
          ? null
          : SpanId.fromId(json['parent_span_id'] as String),
      traceId: SentryId.fromId(json['trace_id'] as String),
      description: json['description'] as String?,
      status: json['status'] == null
          ? null
          : SpanStatus.fromString(json['status'] as String),
      sampled: true,
    );
  }

  /// Item header encoded as JSON
  Map<String, dynamic> toJson() {
    return {
      'span_id': spanId.toString(),
      'trace_id': traceId.toString(),
      'op': operation,
      if (parentSpanId != null) 'parent_span_id': parentSpanId!.toString(),
      if (description != null) 'description': description,
      if (status != null) 'status': status!.toString(),
    };
  }

  SentryTraceContext clone() => SentryTraceContext(
        operation: operation,
        traceId: traceId,
        spanId: spanId,
        description: description,
        status: status,
        parentSpanId: parentSpanId,
        sampled: sampled,
      );

  SentryTraceContext({
    SentryId? traceId,
    SpanId? spanId,
    this.parentSpanId,
    this.sampled,
    required this.operation,
    this.description,
    this.status,
  })  : traceId = traceId ?? SentryId.newId(),
        spanId = spanId ?? SpanId.newId();
}
