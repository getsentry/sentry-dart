import 'package:meta/meta.dart';

import '../../sentry.dart';

/// Represents the Span model based on https://develop.sentry.dev/sdk/telemetry/spans/span-api/
abstract class Span {
  @internal
  const Span();

  /// Gets the name of the span.
  String get name;

  /// Gets the parentSpan.
  /// If null this span has no parent.
  Span? get parentSpan;

  /// Ends the span.
  ///
  /// [endTimestamp] can be used to override the end time.
  /// If omitted, the span ends using the current time.
  void end({DateTime? endTimestamp});

  /// Sets a single attribute.
  ///
  /// Overrides if the attribute already exists.
  void setAttribute(String key, SentryAttribute value);

  /// Sets multiple attributes.
  ///
  /// Overrides if the attributes already exist.
  void setAttributes(Map<String, SentryAttribute> attributes);

  /// Sets the status of the span.
  void setStatus(SpanV2Status status);

  /// Sets the name of the span.
  void setName(String name);

  @internal
  Map<String, dynamic> toJson();
}
