import '../../../sentry.dart';
import 'sentry_metric.dart';

/// Public API for recording metrics
final class SentryMetrics {
  final Hub _hub;
  final ClockProvider _clockProvider;

  SentryMetrics(this._hub, this._clockProvider);

  /// Records a counter metric
  void count(
    String name,
    int value, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) {
    if (!_isEnabled) return;

    final metric = SentryCounterMetric(
        timestamp: _clockProvider(),
        name: name,
        value: value,
        spanId: _hub.scope.span?.context.spanId,
        traceId: _traceIdFromScope(scope),
        attributes: attributes ?? {});

    _hub.captureMetric(metric);
  }

  /// Records a gauge metric
  void gauge(
    String name,
    num value, {
    String? unit,
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) {
    if (!_isEnabled) return;

    final metric = SentryGaugeMetric(
        timestamp: _clockProvider(),
        name: name,
        value: value,
        spanId: _hub.scope.span?.context.spanId,
        traceId: _traceIdFromScope(scope),
        attributes: attributes ?? {});

    _hub.captureMetric(metric);
  }

  /// Records a distribution metric
  void distribution(
    String name,
    num value, {
    String? unit,
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) {
    if (!_isEnabled) return;

    final metric = SentryDistributionMetric(
        timestamp: _clockProvider(),
        name: name,
        value: value,
        unit: unit,
        spanId: _hub.scope.span?.context.spanId,
        traceId: _traceIdFromScope(scope),
        attributes: attributes ?? {});

    _hub.captureMetric(metric);
  }

  bool get _isEnabled => _hub.options.enableMetrics;

  SentryId _traceIdFromScope(Scope? scope) =>
      scope?.propagationContext.traceId ??
      _hub.scope.propagationContext.traceId;
}
