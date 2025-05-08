import 'sentry_id.dart';
import 'sentry_log_level.dart';
import 'sentry_log_attribute.dart';

class SentryLog {
  DateTime timestamp;
  SentryId traceId;
  SentryLogLevel level;
  String body;
  Map<String, SentryLogAttribute> attributes;
  int? severityNumber;

  SentryLog({
    required this.timestamp,
    SentryId? traceId,
    required this.level,
    required this.body,
    required this.attributes,
    this.severityNumber,
  }) : traceId = traceId ?? SentryId.empty();

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'trace_id': traceId.toString(),
      'level': level.value,
      'body': body,
      'attributes':
          attributes.map((key, value) => MapEntry(key, value.toJson())),
      'severity_number': severityNumber ?? level.toSeverityNumber(),
    };
  }
}
