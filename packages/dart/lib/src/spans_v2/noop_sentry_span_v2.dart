part of 'sentry_span_v2.dart';

/// A no-op implementation of [SentrySpanV2].
///
/// Used when tracing is disabled or when span operations should be ignored.
/// All operations are no-ops and the span is never sent to Sentry.
@internal
final class NoOpSentrySpanV2 implements SentrySpanV2 {
  const NoOpSentrySpanV2();

  @override
  SpanId get spanId => SpanId.empty();

  @override
  SentryId get traceId => SentryId.empty();

  @override
  final String name = 'NoOpSentrySpanV2';

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
  Map<String, SentryAttribute> get attributes => const {};

  @override
  void setAttribute(String key, SentryAttribute value) {}

  @override
  void setAttributes(Map<String, SentryAttribute> attributes) {}

  @override
  void end({DateTime? endTimestamp}) {}
}
