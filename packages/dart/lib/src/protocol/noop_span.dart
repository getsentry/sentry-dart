import '../../sentry.dart';

class NoOpSpan implements Span {
  const NoOpSpan();

  @override
  final String name = 'NoOpSpan';

  @override
  final SpanV2Status status = SpanV2Status.ok;

  @override
  void end({DateTime? endTimestamp}) {}

  @override
  Span? get parentSpan => NoOpSpan();

  @override
  void setAttribute(String key, SentryAttribute value) {}

  @override
  void setAttributes(Map<String, SentryAttribute> attributes) {}

  @override
  Map<String, dynamic> toJson() => {};

  @override
  set name(String name) {}

  @override
  set status(SpanV2Status status) {}

  @override
  Map<String, SentryAttribute> get attributes => {};

  @override
  DateTime? get endTimestamp => null;
}
