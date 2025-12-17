import 'package:sentry/sentry.dart';

/// Minimal test span with controllable segment behavior.
class MockSpanV2 extends Span {
  @override
  final String name;

  @override
  final SentryId traceId;

  @override
  final SpanId spanId;

  @override
  final Span? parentSpan;

  late final Span _segmentSpan;

  MockSpanV2({
    required this.name,
    required this.traceId,
    required this.spanId,
    this.parentSpan,
  }) {
    _segmentSpan = parentSpan?.segmentSpan ?? this;
  }

  @override
  Span get segmentSpan => _segmentSpan;

  @override
  set name(String value) {}

  @override
  SpanV2Status get status => SpanV2Status.ok;

  @override
  set status(SpanV2Status value) {}

  @override
  DateTime? get endTimestamp => DateTime.now().toUtc();

  @override
  Map<String, SentryAttribute> get attributes => {};

  @override
  void end({DateTime? endTimestamp}) {}

  @override
  void setAttribute(String key, SentryAttribute value) {}

  @override
  void setAttributes(Map<String, SentryAttribute> attributes) {}

  @override
  bool get isFinished => true;

  @override
  Map<String, dynamic> toJson() => {
        'trace_id': traceId.toString(),
        'span_id': spanId.toString(),
        'name': name,
        'status': status.name,
      };
}
