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
    return SentrySpanContext(
      operation: '',
    );
  }

  /// Item header encoded as JSON
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    return json;
  }

  SentrySpanContext clone() => SentrySpanContext(
        operation: operation,
      );

  // maybe use required
  SentrySpanContext({
    SentryId? traceId,
    SpanId? spanId,
    SpanId? parentId,
    bool? sampled,
    required String operation,
    String? description,
    SpanStatus? status,
    Map<String, String>? tags,
  }) {
    this.traceId = traceId ?? SentryId.newId();
    this.spanId = spanId ?? SpanId.newId();
    this.parentId = parentId;
    this.sampled = sampled;
    this.operation = operation;
    this.description = description;
    this.status = status;
    this.tags = tags ?? {};
  }
}
