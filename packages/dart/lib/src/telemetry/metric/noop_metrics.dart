import '../../../sentry.dart';

final class NoOpSentryMetrics implements SentryMetrics {
  const NoOpSentryMetrics();

  static const instance = NoOpSentryMetrics();

  @override
  void count(String name, int value,
      {Map<String, SentryAttribute>? attributes, Scope? scope}) {}

  @override
  void distribution(String name, num value,
      {String? unit, Map<String, SentryAttribute>? attributes, Scope? scope}) {}

  @override
  void gauge(String name, num value,
      {String? unit, Map<String, SentryAttribute>? attributes, Scope? scope}) {}
}
