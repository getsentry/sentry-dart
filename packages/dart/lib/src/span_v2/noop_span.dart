import '../../sentry.dart';
import 'Span.dart';

class NoOpSpan implements Span {
  @override
  void end({DateTime? endTimestamp}) {}

  @override
  void setAttribute(String key, SentryAttribute value) {}

  @override
  void setAttributes(Map<String, SentryAttribute> attributes) {}

  @override
  void setName(String name) {}

  @override
  void setStatus(SpanV2Status status) {}
}
