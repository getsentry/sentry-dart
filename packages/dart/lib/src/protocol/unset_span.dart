import 'package:meta/meta.dart';

import '../../sentry.dart';

/// This class is a marker class to represent unset / not provided span for startSpan.
/// Since Dart does not have 'undefined' we use this class to circumvent that issue.
@internal
class UnsetSpan extends Span {
  const UnsetSpan();

  @override
  void end({DateTime? endTimestamp}) {
    throw UnimplementedError('$UnsetSpan methods should not be used');
  }

  @override
  void setAttribute(String key, SentryAttribute value) {
    throw UnimplementedError('$UnsetSpan methods should not be used');
  }

  @override
  void setAttributes(Map<String, SentryAttribute> attributes) {
    throw UnimplementedError('$UnsetSpan methods should not be used');
  }

  @override
  void setName(String name) {
    throw UnimplementedError('$UnsetSpan methods should not be used');
  }

  @override
  void setStatus(SpanV2Status status) {
    throw UnimplementedError('$UnsetSpan methods should not be used');
  }

  @override
  Map<String, dynamic> toJson() {
    throw UnimplementedError('$UnsetSpan methods should not be used');
  }
}
