import 'package:meta/meta.dart';

import '../../hint.dart';
import '../../noop_sentry_span.dart';
import '../../protocol.dart';
import '../../sentry_span_interface.dart';
import '../../sentry_trace_context_header.dart';

/// Opaque span handle for instrumentation purposes.
///
/// Packages use this instead of [ISentrySpan] directly, enabling the
/// underlying span implementation to be swapped (e.g., to SentrySpanV2).
@internal
abstract class InstrumentationSpan {
  /// Sets data on the span.
  void setData(String key, dynamic value);

  /// Sets a tag on the span.
  void setTag(String key, String value);

  /// Gets the span status.
  SpanStatus? get status;

  /// Sets the span status.
  set status(SpanStatus? status);

  /// Gets the throwable/exception.
  dynamic get throwable;

  /// Sets the throwable/exception.
  set throwable(dynamic throwable);

  /// Gets the origin.
  String? get origin;

  /// Sets the origin.
  set origin(String? origin);

  /// Finishes the span.
  Future<void> finish({SpanStatus? status, DateTime? endTimestamp, Hint? hint});

  /// Returns the sentry-trace header for distributed tracing.
  SentryTraceHeader toSentryTrace();

  /// Returns the baggage header for distributed tracing.
  SentryBaggageHeader? toBaggageHeader();

  /// Returns the trace context header.
  SentryTraceContextHeader? traceContext();

  /// Returns `true` if this is a no-op span.
  bool get isNoOp;
}

/// Implementation of [InstrumentationSpan] wrapping [ISentrySpan].
///
/// This is the default implementation used when the legacy tracing backend
/// is active. It delegates all operations to the underlying [ISentrySpan].
@internal
class LegacyInstrumentationSpan implements InstrumentationSpan {
  final ISentrySpan _span;

  LegacyInstrumentationSpan(this._span);

  /// Access to the underlying span for internal use (e.g., creating children).
  @internal
  ISentrySpan get underlyingSpan => _span;

  @override
  void setData(String key, dynamic value) => _span.setData(key, value);

  @override
  void setTag(String key, String value) => _span.setTag(key, value);

  @override
  SpanStatus? get status => _span.status;

  @override
  set status(SpanStatus? status) => _span.status = status;

  @override
  dynamic get throwable => _span.throwable;

  @override
  set throwable(dynamic throwable) => _span.throwable = throwable;

  @override
  String? get origin => _span.origin;

  @override
  set origin(String? origin) => _span.origin = origin;

  @override
  Future<void> finish({
    SpanStatus? status,
    DateTime? endTimestamp,
    Hint? hint,
  }) =>
      _span.finish(status: status, endTimestamp: endTimestamp, hint: hint);

  @override
  SentryTraceHeader toSentryTrace() => _span.toSentryTrace();

  @override
  SentryBaggageHeader? toBaggageHeader() => _span.toBaggageHeader();

  @override
  SentryTraceContextHeader? traceContext() => _span.traceContext();

  @override
  bool get isNoOp => _span is NoOpSentrySpan;
}
