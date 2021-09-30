import 'package:meta/meta.dart';

import '../invalid_sentry_trace_header_exception.dart';
import '../protocol.dart';

/// Represents HTTP header "sentry-trace".
@immutable
class SentryTraceHeader {
  static const _traceHeader = 'sentry-trace';

  final SentryId traceId;
  final SpanId spanId;
  final bool? sampled;

  String get name => _traceHeader;

  String get value {
    if (sampled != null) {
      final sampled = this.sampled! ? '1' : '0';
      return '$traceId-$spanId-$sampled';
    } else {
      return '$traceId-$spanId';
    }
  }

  SentryTraceHeader(
    this.traceId,
    this.spanId, {
    bool? sampled,
  }) : sampled = sampled;

  factory SentryTraceHeader.fromTraceHeader(String header) {
    final parts = header.split('-');
    bool? sampled;

    if (parts.length < 2) {
      throw InvalidSentryTraceHeaderException('Header: $header is invalid.');
    } else if (parts.length == 3) {
      sampled = '1' == parts[2];
    }

    final traceId = SentryId.fromId(parts[0]);
    final spanId = SpanId.fromId(parts[1]);

    return SentryTraceHeader(
      traceId,
      spanId,
      sampled: sampled,
    );
  }
}
