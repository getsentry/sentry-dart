part of '../telemetry.dart';

final class NoOpSentrySpanV2 implements SentrySpanV2 {
  const NoOpSentrySpanV2();

  static const instance = NoOpSentrySpanV2();

  @override
  SpanId get spanId => SpanId.empty();

  @override
  final String name = 'NoOpSpan';

  @override
  set name(String name) {}

  @override
  final SentrySpanStatusV2 status = SentrySpanStatusV2.ok;

  @override
  set status(SentrySpanStatusV2 status) {}

  @override
  SentrySpanV2? get parentSpan => null;

  @override
  DateTime? get endTimestamp => null;

  @override
  Map<String, SentryAttribute> get attributes => {};

  @override
  void setAttribute(String key, SentryAttribute value) {}

  @override
  void setAttributes(Map<String, SentryAttribute> attributes) {}

  @override
  void removeAttribute(String key) {}

  @override
  void end({DateTime? endTimestamp}) {}

  @override
  SentryId get traceId => SentryId.empty();
}
