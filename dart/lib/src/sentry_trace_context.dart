import 'package:meta/meta.dart';

import 'protocol.dart';

@immutable
class SentryTraceContext {
  static const String type = 'trace';

  late final SentryId traceId;
  late final SpanId spanId;
  final SpanId? parentId;
  final bool? sampled;
  late final String operation;
  final String? description;
  final SpanStatus? status;

  factory SentryTraceContext.fromJson(Map<String, dynamic> json) {
    // assign empty id if non existent instead of null and new id
    return SentryTraceContext(
      operation: json['op'] as String,
      spanId: SpanId.fromId(['span_id'] as String),
      parentId: json['parent_span_id'] == null
          ? null
          : SpanId.fromId(json['parent_span_id'] as String),
      traceId: json['trace_id'] == null
          ? null
          : SentryId.fromId(json['trace_id'] as String),
      description: json['description'] as String?,
      status: json['status'] == null
          ? null
          : SpanStatus.fromString(json['status'] as String),
    );
  }

  /// Item header encoded as JSON
  Map<String, dynamic> toJson() {
    return {
      'span_id': spanId.toString(),
      'trace_id': traceId.toString(),
      'op': operation,
      if (parentId != null) 'parent_span_id': parentId?.toString(),
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
        parentId: parentId,
        sampled: sampled,
      );

  // maybe use required
  SentryTraceContext({
    SentryId? traceId,
    SpanId? spanId,
    this.parentId,
    this.sampled,
    required this.operation,
    this.description,
    this.status,
  })  : traceId = traceId ?? SentryId.newId(),
        spanId = spanId ?? SpanId.newId();
}
