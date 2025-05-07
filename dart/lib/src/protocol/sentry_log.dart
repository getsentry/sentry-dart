import 'sentry_log_item.dart';

class SentryLog {
  final List<SentryLogItem> items;

  SentryLog({required this.items});

  toJson() {
    return {
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}
