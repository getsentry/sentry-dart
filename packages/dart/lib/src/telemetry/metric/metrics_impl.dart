import '../../../sentry.dart';
import 'metric.dart';
import 'metrics.dart';

typedef CaptureMetricCallback = void Function(SentryMetric metric);
typedef ScopeProvider = Scope Function();

final class DefaultSentryMetrics implements SentryMetrics {
  final CaptureMetricCallback _captureMetricCallback;
  final ClockProvider _clockProvider;
  final ScopeProvider _defaultScopeProvider;

  DefaultSentryMetrics(
      {required CaptureMetricCallback captureMetricCallback,
      required ClockProvider clockProvider,
      required ScopeProvider defaultScopeProvider})
      : _captureMetricCallback = captureMetricCallback,
        _clockProvider = clockProvider,
        _defaultScopeProvider = defaultScopeProvider;

  @override
  void count(
    String name,
    int value, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) {
    final metric = SentryCounterMetric(
        timestamp: _clockProvider(),
        name: name,
        value: value,
        spanId: _activeSpanIdFor(scope),
        traceId: _traceIdFor(scope),
        attributes: attributes ?? {});

    _captureMetricCallback(metric);
  }

  @override
  void gauge(
    String name,
    num value, {
    String? unit,
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) {
    final metric = SentryGaugeMetric(
        timestamp: _clockProvider(),
        name: name,
        value: value,
        spanId: _activeSpanIdFor(scope),
        traceId: _traceIdFor(scope),
        attributes: attributes ?? {});

    _captureMetricCallback(metric);
  }

  @override
  void distribution(
    String name,
    num value, {
    String? unit,
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) {
    final metric = SentryDistributionMetric(
        timestamp: _clockProvider(),
        name: name,
        value: value,
        unit: unit,
        spanId: _activeSpanIdFor(scope),
        traceId: _traceIdFor(scope),
        attributes: attributes ?? {});

    _captureMetricCallback(metric);
  }

  SentryId _traceIdFor(Scope? scope) =>
      (scope ?? _defaultScopeProvider()).propagationContext.traceId;

  SpanId? _activeSpanIdFor(Scope? scope) =>
      (scope ?? _defaultScopeProvider()).span?.context.spanId;
}

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
