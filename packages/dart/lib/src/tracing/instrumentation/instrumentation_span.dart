import 'package:meta/meta.dart';

import '../../protocol.dart';
import '../../sentry_span_interface.dart';

/// Opaque span handle enabling swappable tracing backends.
@internal
abstract class InstrumentationSpan {
  void setData(String key, dynamic value);
  void setTag(String key, String value);
  SpanStatus? get status;
  set status(SpanStatus? status);
  dynamic get throwable;
  set throwable(dynamic throwable);
  String? get origin;
  set origin(String? origin);
  Future<void> finish({SpanStatus? status, DateTime? endTimestamp});
  SentryTraceHeader toSentryTrace();
  SentryBaggageHeader? toBaggageHeader();
}

/// [InstrumentationSpan] implementation wrapping [ISentrySpan].
@internal
class LegacyInstrumentationSpan implements InstrumentationSpan {
  final ISentrySpan _span;

  LegacyInstrumentationSpan(this._span);

  @internal
  ISentrySpan get spanReference => _span;

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
  }) =>
      _span.finish(status: status, endTimestamp: endTimestamp);

  @override
  SentryTraceHeader toSentryTrace() => _span.toSentryTrace();

  @override
  SentryBaggageHeader? toBaggageHeader() => _span.toBaggageHeader();
}
