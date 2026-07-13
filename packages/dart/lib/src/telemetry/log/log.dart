import '../../protocol/sentry_attribute.dart';
import '../../protocol/sentry_id.dart';
import '../../protocol/span_id.dart';
import '../../utils/date_time_extension.dart';
import 'log_level.dart';

class SentryLog {
  DateTime timestamp;
  SentryId traceId;
  SpanId? spanId;
  SentryLogLevel level;
  String body;
  Map<String, SentryAttribute> attributes;
  int? severityNumber;

  SentryLog({
    required this.timestamp,
    required this.traceId,
    required this.level,
    required this.body,
    required this.attributes,
    this.spanId,
    this.severityNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.secondsSinceEpoch,
      'trace_id': traceId.toString(),
      if (spanId != null) 'span_id': spanId.toString(),
      'level': level.value,
      'body': body,
      'attributes':
          attributes.map((key, value) => MapEntry(key, value.toJson())),
      'severity_number': severityNumber ?? level.toSeverityNumber(),
    };
  }
}
