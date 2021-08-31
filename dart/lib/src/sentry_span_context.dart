import '../sentry.dart';

class SentrySpanContext {
  static const String type = 'trace';

  late SentryId traceId;
  late SpanId spanId;
  SpanId? parentId;
  bool? sampled;
  late String operation;
  String? description;
  SpanStatus? status;
  late Map<String, String> tags;

  factory SentrySpanContext.fromJson(Map<String, dynamic> json) {
    // assign empty id if non existent instead of null and new id
    // missing sampled
    return SentrySpanContext(
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
        tags: json['tags'] as Map<String, String>);
  }

  /// Item header encoded as JSON
  Map<String, dynamic> toJson() {
    // missing sampled
    return {
      'span_id': spanId.toString(),
      'trace_id': traceId.toString(),
      'op': operation,
      if (parentId != null) 'parent_span_id': parentId?.toString(),
      if (description != null) 'description': description,
      if (status != null) 'status': status!.toString(),
      if (tags.isNotEmpty) 'tags': tags,
    };
  }

  SentrySpanContext clone() => SentrySpanContext(
        operation: operation,
        traceId: traceId,
        spanId: spanId,
        description: description,
        status: status,
        tags: tags,
        parentId: parentId,
        sampled: sampled,
      );

  // maybe use required
  SentrySpanContext({
    SentryId? traceId,
    SpanId? spanId,
    this.parentId,
    this.sampled,
    required this.operation,
    this.description,
    this.status,
    Map<String, String>? tags,
  })  : traceId = traceId ?? SentryId.newId(),
        spanId = spanId ?? SpanId.newId(),
        tags = tags ?? {};
}
