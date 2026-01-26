import '../../../sentry.dart';

final class NoOpSentryMetrics implements SentryMetrics {
  const NoOpSentryMetrics();

  @override
  void count(
    String name,
    int value, {
    Map<String, SentryAttribute>? attributes,
  }) {}

  @override
  void distribution(
    String name,
    num value, {
    String? unit,
    Map<String, SentryAttribute>? attributes,
  }) {}

  @override
  void gauge(
    String name,
    num value, {
    String? unit,
    Map<String, SentryAttribute>? attributes,
  }) {}
}
