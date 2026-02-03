import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../../utils/internal_logger.dart';

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

@internal
class StreamingInstrumentationSpan implements InstrumentationSpan {
  final SentrySpanV2 _span;
  dynamic _throwable;

  StreamingInstrumentationSpan(this._span);

  @internal
  SentrySpanV2 get spanReference => _span;

  @override
  String? get origin {
    final originAttribute =
        _span.attributes[SemanticAttributesConstants.sentryOrigin];
    return originAttribute?.value as String?;
  }

  @override
  set origin(String? origin) {
    if (origin != null) {
      _span.setAttribute(SemanticAttributesConstants.sentryOrigin,
          SentryAttribute.string(origin));
    }
  }

  @override
  SpanStatus? get status => _convertFromV2Status(_span.status);

  @override
  set status(SpanStatus? status) {
    if (status != null) {
      _span.status = _convertToV2Status(status);
    }
  }

  @override
  dynamic get throwable => _throwable;

  @override
  set throwable(dynamic throwable) => _throwable = throwable;

  @override
  Future<void> finish({SpanStatus? status, DateTime? endTimestamp}) async {
    if (status != null) {
      this.status = status;
    }
    _span.end(endTimestamp: endTimestamp);
  }

  @override
  void setData(String key, dynamic value) {
    if (value is String) {
      _span.setAttribute(key, SentryAttribute.string(value));
    } else if (value is int) {
      _span.setAttribute(key, SentryAttribute.int(value));
    } else if (value is double) {
      _span.setAttribute(key, SentryAttribute.double(value));
    } else if (value is bool) {
      _span.setAttribute(key, SentryAttribute.bool(value));
    } else if (value is SentryAttribute) {
      _span.setAttribute(key, value);
    } else {
      internalLogger.warning(
          '$StreamingInstrumentationSpan: Unsupported data type in setData: $value');
    }
  }

  @override
  void setTag(String key, String value) {
    _span.setAttribute(key, SentryAttribute.string(value));
  }

  @override
  SentryBaggageHeader? toBaggageHeader() {
    if (_span case RecordingSentrySpanV2 recordingSpan) {
      final dsc = recordingSpan.resolveDsc();
      final baggage = dsc.toBaggage();
      return SentryBaggageHeader.fromBaggage(baggage);
    }
    return null;
  }

  @override
  SentryTraceHeader toSentryTrace() {
    if (_span case RecordingSentrySpanV2 recordingSpan) {
      return generateSentryTraceHeader(
        traceId: recordingSpan.traceId,
        spanId: recordingSpan.spanId,
        sampled: recordingSpan.samplingDecision.sampled,
      );
    }
    return generateSentryTraceHeader(
      traceId: _span.traceId,
      spanId: _span.spanId,
      sampled: null,
    );
  }

  SpanStatus _convertFromV2Status(SentrySpanStatusV2 status) {
    switch (status) {
      case SentrySpanStatusV2.ok:
        return SpanStatus.ok();
      case SentrySpanStatusV2.error:
        return SpanStatus.unknownError();
    }
  }

  SentrySpanStatusV2 _convertToV2Status(SpanStatus status) {
    if (status == SpanStatus.ok()) {
      return SentrySpanStatusV2.ok;
    }
    return SentrySpanStatusV2.error;
  }
}
