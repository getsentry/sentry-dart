import '../sentry.dart';
import 'utils.dart';

class NoOpSentrySpan extends ISentrySpan {
  NoOpSentrySpan._();

  static final _instance = NoOpSentrySpan._();

  static final _spanContext = SentrySpanContext(
    traceId: SentryId.empty(),
    spanId: SpanId.empty(),
    operation: 'noop',
  );

  static final _timestamp = getUtcDateTime();

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
  SentrySpanContext get context => _spanContext;

  @override
  SpanStatus? get status => null;

  @override
  DateTime get startTimestamp => _timestamp;

  @override
  DateTime? get timestamp => null;

  @override
  bool get finished => false;
}
