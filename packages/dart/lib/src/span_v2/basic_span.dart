import '../../sentry.dart';
import 'span.dart';
import 'span_v2_status.dart';

class BasicSpan implements Span {
  @override
  void end({DateTime? endTimestamp}) {
    // TODO: implement end
  }

  @override
  void setAttribute(String key, SentryAttribute value) {
    // TODO: implement setAttribute
  }

  @override
  void setAttributes(Map<String, SentryAttribute> attributes) {
    // TODO: implement setAttributes
  }

  @override
  void setName(String name) {
    // TODO: implement setName
  }

  @override
  void setStatus(SpanV2Status status) {
    // TODO: implement setStatus
  }
}
