import '../../../sentry.dart';

abstract interface class SentryMetrics {
  void count(String name, int value,
      {Map<String, SentryAttribute>? attributes, Scope? scope});
  void distribution(String name, num value,
      {String? unit, Map<String, SentryAttribute>? attributes, Scope? scope});
  void gauge(String name, num value,
      {String? unit, Map<String, SentryAttribute>? attributes, Scope? scope});
}
