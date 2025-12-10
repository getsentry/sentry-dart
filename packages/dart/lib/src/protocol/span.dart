import 'package:meta/meta.dart';

import '../../sentry.dart';

// Span specs: https://develop.sentry.dev/sdk/telemetry/spans/span-api/

/// Represents a basic telemetry span.
abstract class Span {
  @internal
  const Span();

  /// Gets the id of the span.
  SpanId get spanId;

  /// Gets the name of the span.
  String get name;

  /// Sets the name of the span.
  set name(String name);

  /// Gets the parent span.
  /// If null this span has no parent.
  Span? get parentSpan;

  /// Gets the status of the span.
  SpanV2Status get status;

  /// Sets the status of the span.
  set status(SpanV2Status status);

  /// Gets the end timestamp of the span.
  DateTime? get endTimestamp;

  /// Gets a read-only view of the attributes of the span.
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

  @internal
  bool get isFinished;

  @internal
  Map<String, dynamic> toJson();
}
