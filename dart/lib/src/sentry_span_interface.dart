import 'package:meta/meta.dart';

import 'protocol.dart';
import 'tracing.dart';

/// Represents performance monitoring Span.
abstract class ISentrySpan {
  /// Starts a child Span.
  ISentrySpan startChild(
    String operation, {
    String? description,
    DateTime? startTimestamp,
  });

  /// Sets the tag on span or transaction.
  void setTag(String key, String value);

  /// Removes the tag on span or transaction.
  void removeTag(String key);

  /// Sets extra data on span or transaction.
  void setData(String key, dynamic value);

  /// Removes extra data on span or transaction.
  void removeData(String key);

  /// Sets span timestamp marking this span as finished.
  Future<void> finish({SpanStatus? status, DateTime? endTimestamp}) async {}

  /// Gets span status.
  SpanStatus? get status;

  /// Sets span status.
  set status(SpanStatus? status);

  /// Gets the span context.
  SentrySpanContext get context;

  /// Returns the end timestamp if finished
  DateTime? get endTimestamp;

  /// Returns the star timestamp
  DateTime get startTimestamp;

  /// Returns true if span is finished
  bool get finished;

  /// Returns the associated error
  dynamic get throwable;

  /// Associated the error with the span
  set throwable(dynamic throwable);

  @internal
  SentryTracesSamplingDecision? get samplingDecision;

  /// Returns the trace information that could be sent as a sentry-trace header.
  SentryTraceHeader toSentryTrace();

  /// Set observed measurement for this transaction.
  void setMeasurement(
    String name,
    num value, {
    SentryMeasurementUnit? unit,
  });

  /// Returns the baggage that can be sent as "baggage" header.
  @experimental
  SentryBaggageHeader? toBaggageHeader();

  /// Returns the trace context.
  @experimental
  SentryTraceContextHeader? traceContext();

  @internal
  void scheduleFinish();
}
