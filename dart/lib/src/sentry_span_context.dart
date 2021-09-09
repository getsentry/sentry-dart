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
