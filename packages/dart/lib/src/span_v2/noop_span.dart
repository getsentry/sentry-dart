import '../../sentry.dart';
import 'span.dart';
import 'span_v2_status.dart';

class NoOpSpan implements Span {
  const NoOpSpan();

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

  @override
  Map<String, dynamic> toJson() => {};
}
