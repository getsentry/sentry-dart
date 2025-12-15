import 'package:meta/meta.dart';

import '../../sentry.dart';

/// This class is a marker class to represent unset / not provided span for startSpan.
/// Since Dart does not have 'undefined' we use this class to circumvent that issue.
@internal
class UnsetSpan extends Span {
  const UnsetSpan();

  @override
  SpanId get spanId =>
      throw UnimplementedError('$UnsetSpan apis should not be used');

  @override
  String get name =>
      throw UnimplementedError('$UnsetSpan apis should not be used');

  @override
  set name(String name) =>
      throw UnimplementedError('$UnsetSpan apis should not be used');

  @override
  SpanV2Status get status =>
      throw UnimplementedError('$UnsetSpan apis should not be used');

  @override
  set status(SpanV2Status status) =>
      throw UnimplementedError('$UnsetSpan apis should not be used');

  @override
  Span? get parentSpan =>
      throw UnimplementedError('$UnsetSpan apis should not be used');

  @override
  DateTime? get endTimestamp =>
      throw UnimplementedError('$UnsetSpan apis should not be used');

  @override
  Map<String, SentryAttribute> get attributes =>
      throw UnimplementedError('$UnsetSpan apis should not be used');

  @override
  bool get isFinished =>
      throw UnimplementedError('$UnsetSpan apis should not be used');

  @override
  void setAttribute(String key, SentryAttribute value) {
    throw UnimplementedError('$UnsetSpan apis should not be used');
  }

  @override
  void setAttributes(Map<String, SentryAttribute> attributes) {
    throw UnimplementedError('$UnsetSpan apis should not be used');
  }

  @override
  void end({DateTime? endTimestamp}) {
    throw UnimplementedError('$UnsetSpan apis should not be used');
  }

  @override
  Map<String, dynamic> toJson() {
    throw UnimplementedError('$UnsetSpan apis should not be used');
  }

  @override
  Span get segmentSpan => throw UnimplementedError();

  @override
  SentryId get traceId => throw UnimplementedError();
}
