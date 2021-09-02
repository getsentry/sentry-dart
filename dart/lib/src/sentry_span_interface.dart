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

  Future<void> finish({
    SpanStatus? status,
  });

  SpanStatus? get status;

  SentrySpanContext get context;

  DateTime? get timestamp;

  DateTime get startTimestamp;
  // missing toTraceHeader

  // internal
  Map<String, dynamic> toJson() => {};

  bool get finished;
}
