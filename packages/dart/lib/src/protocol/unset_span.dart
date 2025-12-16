import 'package:meta/meta.dart';

import '../../sentry.dart';

/// This class is a marker class to represent unset / not provided span for startSpan.
/// Since Dart does not have 'undefined' we use this class to circumvent that issue.
@internal
class UnsetSpan extends Span {
  const UnsetSpan();

  static Never _throw() =>
      throw UnimplementedError('$UnsetSpan APIs should not be used');

  @override
  SpanId get spanId => _throw();

  @override
  String get name => _throw();

  @override
  set name(String name) => _throw();

  @override
  SpanV2Status get status => _throw();

  @override
  set status(SpanV2Status status) => _throw();

  @override
  Span? get parentSpan => _throw();

  @override
  DateTime? get endTimestamp => _throw();

  @override
  Map<String, SentryAttribute> get attributes => _throw();

  @override
  bool get isFinished => _throw();

  @override
  void setAttribute(String key, SentryAttribute value) => _throw();

  @override
  void setAttributes(Map<String, SentryAttribute> attributes) => _throw();

  @override
  void end({DateTime? endTimestamp}) => _throw();

  @override
  Map<String, dynamic> toJson() => _throw();

  @override
  Span get segmentSpan => _throw();

  @override
  SentryId get traceId => _throw();
}
