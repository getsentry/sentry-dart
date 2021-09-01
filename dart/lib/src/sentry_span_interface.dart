import '../sentry.dart';

abstract class ISentrySpan {
  ISentrySpan startChild(
    String operation, {
    String? description,
  });

  void setTag(String key, String value);

  void removeTag(String key);

  void setData(String key, dynamic value);

  void removeData(String key);

  // Future because finish calls hub.captureTransaction, should we do a Future or not?
  Future<void> finish({
    SpanStatus? status,
  });

  SpanStatus? get status;

  SentrySpanContext get context;

  DateTime? get timestamp;

  DateTime get startTimestamp;
  // missing toTraceHeader, maybe isFinished

  // internal
  Map<String, dynamic> toJson() => {};
}
