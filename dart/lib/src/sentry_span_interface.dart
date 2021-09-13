import 'package:meta/meta.dart';

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

  set status(SpanStatus? status);

  SentrySpanContext get context;

  DateTime? get endTimestamp;

  DateTime get startTimestamp;
  // missing toTraceHeader

  bool get finished;

  dynamic get throwable;

  set throwable(dynamic throwable);

  @internal
  bool? get sampled;
}
