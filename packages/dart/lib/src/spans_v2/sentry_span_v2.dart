// Span specs: https://develop.sentry.dev/sdk/telemetry/spans/span-api/

import 'package:meta/meta.dart';

import '../../sentry.dart';
import '../telemetry_processing/envelope_builder.dart';
import '../telemetry_processing/json_encodable.dart';
import '../telemetry_processing/telemetry_processor.dart';
import 'sentry_span_context_v2.dart';

part 'noop_sentry_span_v2.dart';
part 'unset_sentry_span_v2.dart';
part 'recording_sentry_span_v2.dart';

/// Represents a basic telemetry span.
///
/// This is the public API for spans. Users interact with this interface
/// to set attributes, update status, and end spans.
///
/// See also:
/// - [Sentry.startSpan] to create a new span.
abstract final class SentrySpanV2 {
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

  /// Gets a read-only view of the attributes of the span using
  /// [Map.unmodifiable](https://api.flutter.dev/flutter/dart-core/Map/Map.unmodifiable.html).
  ///
  /// The returned map must not be mutated by callers.
  Map<String, SentryAttribute> get attributes;

  /// Ends the span.
  ///
  /// [endTimestamp] can be used to override the end time.
  /// If omitted, the span ends using the current time when end is executed.
  void end({DateTime? endTimestamp});

  /// Sets a single attribute.
  ///
  /// Overrides if the attribute already exists.
  void setAttribute(String key, SentryAttribute value);

  /// Sets multiple attributes.
  ///
  /// Overrides if the attributes already exist.
  void setAttributes(Map<String, SentryAttribute> attributes);
}
