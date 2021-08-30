import '../sentry.dart';

class SentrySpanContext {
  late SentryId traceId;
  late SpanId spanId;
  SpanId? parentId;
  late bool sampled;
  late String operation;
  String? description;
  SpanStatus? status;
  late Map<String, String> tags;

  // mayve use required
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
    this.sampled = sampled ?? false;
    this.operation = operation;
    this.description = description;
    this.status = status;
    this.tags = tags ?? {};
  }
}
