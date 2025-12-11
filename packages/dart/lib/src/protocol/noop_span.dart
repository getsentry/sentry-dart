import '../../sentry.dart';

class NoOpSpan implements Span {
  const NoOpSpan();

  @override
  SpanId get spanId => SpanId.empty();

  @override
  final String name = 'NoOpSpan';

  @override
  set name(String name) {}

  @override
  final SpanV2Status status = SpanV2Status.ok;

  @override
  set status(SpanV2Status status) {}

  @override
  Span? get parentSpan => null;

  @override
  Span get segmentSpan => this;

  @override
  SentryId get traceId => SentryId.empty();

  @override
  String get segmentKey => '';

  @override
  DateTime? get endTimestamp => null;

  @override
  Map<String, SentryAttribute> get attributes => {};

  @override
  bool get isFinished => false;

  @override
  void setAttribute(String key, SentryAttribute value) {}

  @override
  void setAttributes(Map<String, SentryAttribute> attributes) {}

  @override
  void end({DateTime? endTimestamp}) {}

  @override
  Map<String, dynamic> toJson() => {};
}
