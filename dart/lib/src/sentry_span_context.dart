// import 'package:meta/meta.dart';

import '../sentry.dart';

// @immutable
// SpanContext is the attribute collection for a Span (Can be an implementation detail). When possible SpanContext should be immutable.
// status and sampled should be mutable, so how we do it? clone it?
class SentrySpanContext {
  final SentryId _traceId;
  final SpanId _spanId;
  final SpanId? _parentSpanId;
  bool? sampled;
  late final String _operation;
  final String? _description;
  SpanStatus? status;
  final Map<String, String> _tags;

  // factory SentrySpanContext.fromJson(Map<String, dynamic> json) {
  //   return SentrySpanContext(
  //       operation: json['op'] as String,
  //       spanId: SpanId.fromId(['span_id'] as String),
  //       parentSpanId: json['parent_span_id'] == null
  //           ? null
  //           : SpanId.fromId(json['parent_span_id'] as String),
  //       traceId: SentryId.fromId(json['trace_id'] as String),
  //       description: json['description'] as String?,
  //       status: json['status'] == null
  //           ? null
  //           : SpanStatus.fromString(json['status'] as String),
  //       tags: json['tags'] as Map<String, String>,
  //       sampled: true);
  // }

  /// Item header encoded as JSON
  Map<String, dynamic> toJson() {
    return {
      'span_id': _spanId.toString(),
      'trace_id': _traceId.toString(),
      'op': _operation,
      if (_parentSpanId != null) 'parent_span_id': _parentSpanId?.toString(),
      if (_description != null) 'description': _description,
      if (status != null) 'status': status.toString(),
      if (_tags.isNotEmpty) 'tags': _tags,
    };
  }

  // SentrySpanContext copyWith() => SentrySpanContext(
  //       operation: _operation,
  //       traceId: _traceId,
  //       spanId: _spanId,
  //       description: _description,
  //       status: status,
  //       tags: _tags,
  //       parentSpanId: _parentSpanId,
  //       sampled: sampled,
  //     );

  SentrySpanContext({
    SentryId? traceId,
    SpanId? spanId,
    SpanId? parentSpanId,
    this.sampled,
    required String operation,
    String? description,
    this.status,
    Map<String, String>? tags,
  })  : _traceId = traceId ?? SentryId.newId(),
        _spanId = spanId ?? SpanId.newId(),
        _tags = tags ?? {},
        _parentSpanId = parentSpanId,
        _operation = operation,
        _description = description;

  SentryId get traceId => _traceId;
  SpanId get spanId => _spanId;
  SpanId? get parentSpanId => _parentSpanId;
  String get operation => _operation;
  String? get description => _description;
  Map<String, String> get tags => _tags;
}
