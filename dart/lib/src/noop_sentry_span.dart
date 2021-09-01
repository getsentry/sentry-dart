import '../sentry.dart';
import 'utils.dart';

class NoOpSentrySpan extends ISentrySpan {
  NoOpSentrySpan._();

  static final NoOpSentrySpan _instance = NoOpSentrySpan._();

  factory NoOpSentrySpan() {
    return _instance;
  }

  @override
  Future<void> finish({SpanStatus? status}) => Future.value();

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
  SentrySpanContext get context => SentrySpanContext(operation: 'noop');

  @override
  SpanStatus? get status => null;

  @override
  DateTime get startTimestamp => getUtcDateTime();

  @override
  DateTime? get timestamp => null;
}
