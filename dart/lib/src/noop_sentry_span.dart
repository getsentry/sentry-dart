import 'metrics/local_metrics_aggregator.dart';
import 'protocol.dart';
import 'tracing.dart';
import 'utils.dart';

class NoOpSentrySpan extends ISentrySpan {
  NoOpSentrySpan._();

  static final _instance = NoOpSentrySpan._();

  static final _spanContext = SentrySpanContext(
    traceId: SentryId.empty(),
    spanId: SpanId.empty(),
    operation: 'noop',
  );

  static final _header = SentryTraceHeader(
    SentryId.empty(),
    SpanId.empty(),
    sampled: false,
  );

  static final _timestamp = getUtcDateTime();

  factory NoOpSentrySpan() {
    return _instance;
  }

  @override
  Future<void> finish({SpanStatus? status, DateTime? endTimestamp}) async {}

  @override
  void removeData(String key) {}

  @override
  void removeTag(String key) {}

  @override
  void setData(String key, value) {}

  @override
  void setTag(String key, String value) {}

  @override
  ISentrySpan startChild(
    String operation, {
    String? description,
    DateTime? startTimestamp,
  }) =>
      NoOpSentrySpan();

  @override
  SentrySpanContext get context => _spanContext;

  @override
  String? get origin => null;

  @override
  set origin(String? origin) {}

  @override
  SpanStatus? get status => null;

  @override
  DateTime get startTimestamp => _timestamp;

  @override
  DateTime? get endTimestamp => null;

  @override
  bool get finished => false;

  @override
  dynamic get throwable => null;

  @override
  set throwable(throwable) {}

  @override
  set status(SpanStatus? status) {}

  @override
  SentryTraceHeader toSentryTrace() => _header;

  @override
  void setMeasurement(String name, num value, {SentryMeasurementUnit? unit}) {}

  @override
  SentryBaggageHeader? toBaggageHeader() => null;

  @override
  SentryTraceContextHeader? traceContext() => null;

  @override
  SentryTracesSamplingDecision? get samplingDecision => null;

  @override
  void scheduleFinish() {}

  @override
  LocalMetricsAggregator? get localMetricsAggregator => null;
}
