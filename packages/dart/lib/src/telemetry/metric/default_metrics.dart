import 'dart:async';

import '../../../sentry.dart';
import '../../utils/internal_logger.dart';
import 'metric.dart';

typedef CaptureMetricCallback = Future<void> Function(SentryMetric metric);
typedef ScopeProvider = Scope Function();

final class DefaultSentryMetrics implements SentryMetrics {
  final CaptureMetricCallback _captureMetricCallback;
  final ClockProvider _clockProvider;
  final ScopeProvider _scopeProvider;

  DefaultSentryMetrics(
      {required CaptureMetricCallback captureMetricCallback,
      required ClockProvider clockProvider,
      required ScopeProvider scopeProvider})
      : _captureMetricCallback = captureMetricCallback,
        _clockProvider = clockProvider,
        _scopeProvider = scopeProvider;

  @override
  void count(
    String name,
    int value, {
    Map<String, SentryAttribute>? attributes,
  }) {
    internalLogger.debug(() =>
        'Sentry.metrics.count("$name", $value) called with attributes ${_formatAttributes(attributes)}');

    final metric = SentryCounterMetric(
        timestamp: _clockProvider(),
        name: name,
        value: value,
        spanId: _scopeProvider().span?.context.spanId,
        traceId: _scopeProvider().propagationContext.traceId,
        attributes: attributes ?? {});

    unawaited(_captureMetricCallback(metric));
  }

  @override
  void gauge(
    String name,
    num value, {
    String? unit,
    Map<String, SentryAttribute>? attributes,
  }) {
    internalLogger.debug(() =>
        'Sentry.metrics.gauge("$name", $value${_formatUnit(unit)}) called with attributes ${_formatAttributes(attributes)}');

    final metric = SentryGaugeMetric(
        timestamp: _clockProvider(),
        name: name,
        value: value,
        unit: unit,
        spanId: _scopeProvider().span?.context.spanId,
        traceId: _scopeProvider().propagationContext.traceId,
        attributes: attributes ?? {});

    unawaited(_captureMetricCallback(metric));
  }

  @override
  void distribution(
    String name,
    num value, {
    String? unit,
    Map<String, SentryAttribute>? attributes,
  }) {
    internalLogger.debug(() =>
        'Sentry.metrics.distribution("$name", $value${_formatUnit(unit)}) called with attributes ${_formatAttributes(attributes)}');

    final metric = SentryDistributionMetric(
        timestamp: _clockProvider(),
        name: name,
        value: value,
        unit: unit,
        spanId: _scopeProvider().span?.context.spanId,
        traceId: _scopeProvider().propagationContext.traceId,
        attributes: attributes ?? {});

    unawaited(_captureMetricCallback(metric));
  }

  String _formatUnit(String? unit) => unit != null ? ', unit: $unit' : '';

  String _formatAttributes(Map<String, SentryAttribute>? attributes) {
    final formatted = attributes?.toFormattedString() ?? '';
    return formatted.isEmpty ? '' : ' $formatted';
  }
}
