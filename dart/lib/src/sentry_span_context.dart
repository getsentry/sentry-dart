import '../sentry.dart';

class SentrySpanContext {
  late SentryId traceId;
  late SpanId spanId;
  SpanId? parentSpanId;
  late bool sampled;
  late String operation;
  String? description;
  late SpanStatus status;
  late Map<String, String> tags;

  // mayve use required
  SentrySpanContext({
    SentryId? traceId,
    SpanId? spanId,
    SpanId? parentSpanId,
    bool? sampled,
    String? operation,
    SpanStatus? status,
    Map<String, String>? tags,
  }) {
    this.traceId = traceId ?? SentryId.newId();
    this.spanId = spanId ?? SpanId.newId();
    this.parentSpanId = parentSpanId;
    this.sampled = sampled ?? false;
    this.operation = operation ?? '';
    this.status = status ?? SpanStatus.unknown();
    this.tags = tags ?? {};
  }
}
