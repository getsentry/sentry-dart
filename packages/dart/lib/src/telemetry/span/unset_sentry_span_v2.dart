part of 'sentry_span_v2.dart';

/// This class is a marker class to represent unset / not provided span for startInactiveSpan.
/// Since Dart does not have 'undefined' we use this class to circumvent that issue.
final class UnsetSentrySpanV2 implements SentrySpanV2 {
  const UnsetSentrySpanV2();

  static Never _throw() =>
      throw UnimplementedError('$UnsetSentrySpanV2 APIs should not be used');

  @override
  SpanId get spanId => _throw();

  @override
  String get name => _throw();

  @override
  set name(String name) => _throw();

  @override
  SentrySpanStatusV2 get status => _throw();

  @override
  set status(SentrySpanStatusV2 status) => _throw();

  @override
  SentrySpanV2? get parentSpan => _throw();

  @override
  DateTime get startTimestamp => _throw();

  @override
  DateTime? get endTimestamp => _throw();

  @override
  Map<String, SentryAttribute> get attributes => _throw();

  @override
  void end({DateTime? endTimestamp}) => _throw();

  @override
  SentryId get traceId => _throw();

  @override
  void setAttribute(String key, SentryAttribute value) => _throw();

  @override
  void setAttributes(Map<String, SentryAttribute> attributes) => _throw();

  @override
  void removeAttribute(String key) => _throw();

  @override
  bool get isEnded => _throw();
}
