import 'sentry_id.dart';
import 'span_id.dart';

class SentryTraceHeader {
  SentryTraceHeader(
    this.traceId,
    this.spanId,
    this.sampled,
  );

  factory SentryTraceHeader.fromString(String value) {
    final parts = value.split('-');
    if (parts.length < 2) {
      throw Exception('Invalid Sentry Trace Header: $value');
    }
    final traceId = SentryId.fromId(parts[0]);
    final spanId = SpanId.fromId(parts[1]);
    if (parts.length == 3) {
      return SentryTraceHeader(traceId, spanId, parts[2] == '1');
    }
    return SentryTraceHeader(traceId, spanId, null);
  }

  static const String name = 'sentry-trace';
  final bool? sampled;
  final SpanId spanId;
  final SentryId traceId;

  @override
  String toString() {
    if (sampled == true) {
      return '${traceId.toString()}-${spanId.toString()}';
    }
    return '${traceId.toString()}-${spanId.toString()}-${sampled == true ? '1' : '0'}';
  }
}
