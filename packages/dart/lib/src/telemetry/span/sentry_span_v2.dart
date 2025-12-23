// Span specs: https://develop.sentry.dev/sdk/telemetry/spans/span-api/

import '../../../sentry.dart';
import 'sentry_span_status_v2.dart';

part 'unset_sentry_span_v2.dart';
part 'recording_sentry_span_v2.dart';
part 'noop_sentry_span_v2.dart';

/// Represents a basic telemetry span.
sealed class SentrySpanV2 {
  /// Gets the id of the trace this span belongs to.
  SentryId get traceId;

  /// Gets the id of the span.
  SpanId get spanId;

  /// Gets the name of the span.
  String get name;

  /// Sets the name of the span.
  set name(String name);

  /// Gets the parent span.
  SentrySpanV2? get parentSpan;

  /// Gets the status of the span.
  SentrySpanStatusV2 get status;

  /// Sets the status of the span.
  set status(SentrySpanStatusV2 status);

  /// Gets the end timestamp of the span.
  DateTime? get endTimestamp;

  /// Returns whether this span has ended.
  bool get isEnded;

  /// Ends the span.
  ///
  /// [endTimestamp] can be used to override the end time.
  /// If omitted, the span ends using the current time when end is executed.
  void end({DateTime? endTimestamp});

  /// Gets a read-only view of the attributes of the span using [Map.unmodifiable](https://api.flutter.dev/flutter/dart-core/Map/Map.unmodifiable.html).
  ///
  /// The returned map must not be mutated by callers.
  Map<String, SentryAttribute> get attributes;

  /// Sets an attribute, replacing any existing attribute with the same key.
  void setAttribute(String key, SentryAttribute value);

  /// Sets attributes, replacing existing attributes with the same keys.
  void setAttributes(Map<String, SentryAttribute> attributes);

  /// Removes an attribute with a matching key.
  void removeAttribute(String key);
}
