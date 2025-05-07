import 'sentry_id.dart';
import 'sentry_log_level.dart';
import 'sentry_log_attribute.dart';

class SentryLogItem {
  DateTime timestamp;
  SentryId traceId;
  SentryLogLevel level;
  String body;
  Map<String, SentryLogAttribute> attributes;

  SentryLogItem({
    required this.timestamp,
    required this.traceId,
    required this.level,
    required this.body,
    required this.attributes,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'trace_id': traceId.toString(),
      'level': level.value,
      'body': body,
      'attributes':
          attributes.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}
