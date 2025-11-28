import '../../sentry.dart';

class SimpleSpan implements Span {
  final Hub hub;
  final Span? parentSpan;

  SimpleSpan({required this.parentSpan, required this.hub});

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

  @override
  Map<String, dynamic> toJson() {
    // TODO: implement toJson
    throw UnimplementedError();
  }
}
