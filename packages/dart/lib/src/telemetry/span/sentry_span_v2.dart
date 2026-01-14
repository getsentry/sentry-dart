// Span specs: https://develop.sentry.dev/sdk/telemetry/spans/span-api/

import '../../../sentry.dart';
import '../../utils/internal_logger.dart';
import 'sentry_span_status_v2.dart';

part 'unset_sentry_span_v2.dart';
part 'recording_sentry_span_v2.dart';
part 'noop_sentry_span_v2.dart';

/// Represents a basic telemetry span.
sealed class SentrySpanV2 {
  /// The id of the trace this span belongs to.
  SentryId get traceId;

  /// The id of this span.
  SpanId get spanId;

  /// The name of this span.
  String get name;

  /// Sets the name of this span.
  set name(String name);

  /// The parent span of this span.
  SentrySpanV2? get parentSpan;

  /// The status of this span.
  SentrySpanStatusV2 get status;

  /// Sets the status of this span.
  set status(SentrySpanStatusV2 status);

  /// The start timestamp of this span.
  DateTime get startTimestamp;

  /// The end timestamp of this span.
  ///
  /// Returns null if the span has not ended yet.
  DateTime? get endTimestamp;

  /// Whether this span has ended.
  bool get isEnded;

  /// Ends this span.
  ///
  /// [endTimestamp] can be used to override the end time.
  /// If omitted, this span ends using the current time when end is executed.
  void end({DateTime? endTimestamp});

  /// The read-only view of the attributes of this span using [Map.unmodifiable](https://api.flutter.dev/flutter/dart-core/Map/Map.unmodifiable.html).
  ///
  /// The returned map must not be mutated by callers.
  Map<String, SentryAttribute> get attributes;

  /// Sets an attribute on this span, replacing any existing attribute with the same key.
  void setAttribute(String key, SentryAttribute value);

  /// Sets attributes on this span, replacing existing attributes with the same keys.
  void setAttributes(Map<String, SentryAttribute> attributes);

  /// Removes an attribute on this span with a matching key.
  void removeAttribute(String key);
}
