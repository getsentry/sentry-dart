import 'sentry_attribute.dart';
import 'sentry_id.dart';
import 'sentry_log_level.dart';

class SentryLog {
  DateTime timestamp;
  SentryId traceId;
  SentryLogLevel level;
  String body;
  Map<String, SentryAttribute> attributes;
  int? severityNumber;

  /// The traceId is initially an empty default value and is populated during event processing;
  /// by the time processing completes, it is guaranteed to be a valid non-empty trace id.
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
