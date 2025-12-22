// Span specs: https://develop.sentry.dev/sdk/telemetry/spans/span-api/

part of '../telemetry.dart';

/// Represents a basic telemetry span.
sealed class SentrySpanV2 implements MutableAttributes {
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

  /// Ends the span.
  ///
  /// [endTimestamp] can be used to override the end time.
  /// If omitted, the span ends using the current time when end is executed.
  void end({DateTime? endTimestamp});
}
