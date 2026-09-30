import 'dart:async';

import '../../../sentry.dart';
import '../../utils/internal_logger.dart';

typedef CaptureMetricCallback = Future<void> Function(SentryMetric metric);
typedef ScopeProvider = Scope Function();

final class DefaultSentryMetrics implements SentryMetrics {
  final CaptureMetricCallback _captureMetricCallback;
  final ClockProvider _clockProvider;
  final ScopeProvider _scopeProvider;
  final SentrySpanV2? Function()? _activeSpanProvider;

  DefaultSentryMetrics({
    required this._captureMetricCallback,
    required this._clockProvider,
    required this._scopeProvider,
    this._activeSpanProvider,
  });

  @override
  void count(
    String name,
    int value, {
    Map<String, SentryAttribute>? attributes,
  }) {
    internalLogger.debug(
      () =>
          'Sentry.metrics.count("$name", $value) called with attributes ${_formatAttributes(attributes)}',
    );

    final activeSpan = _activeSpanProvider?.call();
    final scope = _scopeProvider();
    final metric = SentryCounterMetric(
      timestamp: _clockProvider(),
      name: name,
      value: value,
      spanId: activeSpan?.spanId ?? scope.span?.context.spanId,
      traceId: activeSpan?.traceId ?? scope.propagationContext.traceId,
      attributes: attributes ?? {},
    );

    unawaited(_captureMetricCallback(metric));
  }

  @override
  void gauge(
    String name,
    num value, {
    String? unit,
    Map<String, SentryAttribute>? attributes,
  }) {
    internalLogger.debug(
      () =>
          'Sentry.metrics.gauge("$name", $value${_formatUnit(unit)}) called with attributes ${_formatAttributes(attributes)}',
    );

    final activeSpan = _activeSpanProvider?.call();
    final scope = _scopeProvider();
    final metric = SentryGaugeMetric(
      timestamp: _clockProvider(),
      name: name,
      value: value,
      unit: unit,
      spanId: activeSpan?.spanId ?? scope.span?.context.spanId,
      traceId: activeSpan?.traceId ?? scope.propagationContext.traceId,
      attributes: attributes ?? {},
    );

    unawaited(_captureMetricCallback(metric));
  }

  @override
  void distribution(
    String name,
    num value, {
    String? unit,
    Map<String, SentryAttribute>? attributes,
  }) {
    internalLogger.debug(
      () =>
          'Sentry.metrics.distribution("$name", $value${_formatUnit(unit)}) called with attributes ${_formatAttributes(attributes)}',
    );

    final activeSpan = _activeSpanProvider?.call();
    final scope = _scopeProvider();
    final metric = SentryDistributionMetric(
      timestamp: _clockProvider(),
      name: name,
      value: value,
      unit: unit,
      spanId: activeSpan?.spanId ?? scope.span?.context.spanId,
      traceId: activeSpan?.traceId ?? scope.propagationContext.traceId,
      attributes: attributes ?? {},
    );

    unawaited(_captureMetricCallback(metric));
  }

  String _formatUnit(String? unit) => unit != null ? ', unit: $unit' : '';

  String _formatAttributes(Map<String, SentryAttribute>? attributes) {
    final formatted = attributes?.toFormattedString() ?? '';
    return formatted.isEmpty ? '' : ' $formatted';
  }
}
