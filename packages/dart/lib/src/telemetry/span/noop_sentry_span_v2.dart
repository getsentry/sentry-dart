part of 'sentry_span_v2.dart';

final class NoOpSentrySpanV2 implements SentrySpanV2 {
  const NoOpSentrySpanV2({this.recordingParent, this.isIgnored = false});

  static const instance = NoOpSentrySpanV2();

  factory NoOpSentrySpanV2.ignored(RecordingSentrySpanV2 parent) =>
      NoOpSentrySpanV2(recordingParent: parent, isIgnored: true);

  /// Nearest recording ancestor. Only set when [isIgnored] is true.
  @internal
  final RecordingSentrySpanV2? recordingParent;

  /// Whether this was created by an ignoreSpans rule (vs unsampled/disabled).
  @internal
  final bool isIgnored;

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
  DateTime get startTimestamp => DateTime.fromMillisecondsSinceEpoch(0);

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

  @override
  bool get isEnded => false;
}
