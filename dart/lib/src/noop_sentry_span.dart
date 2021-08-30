import '../sentry.dart';

class NoOpSentrySpan implements ISentrySpan {
  NoOpSentrySpan._();

  static final NoOpSentrySpan _instance = NoOpSentrySpan._();

  factory NoOpSentrySpan() {
    return _instance;
  }

  @override
  void finish({SpanStatus? status}) {}

  @override
  void removeData(String key) {}

  @override
  void removeTag(String key) {}

  @override
  void setData(String key, value) {}

  @override
  void setTag(String key, String value) {}

  @override
  ISentrySpan startChild(String operation, {String? description}) {
    return NoOpSentrySpan();
  }

  @override
  // TODO: implement context
  SentrySpanContext get context => throw UnimplementedError();

  @override
  // TODO: implement status
  SpanStatus? get status => null;
}
