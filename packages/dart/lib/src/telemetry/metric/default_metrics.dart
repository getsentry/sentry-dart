import 'dart:async';

import '../../../sentry.dart';
import '../../utils/internal_logger.dart';
import '../telemetry_trace_context.dart';

typedef CaptureMetricCallback = Future<void> Function(SentryMetric metric);

final class DefaultSentryMetrics implements SentryMetrics {
  final CaptureMetricCallback _captureMetricCallback;
  final ClockProvider _clockProvider;
  final TelemetryTraceContextProvider _traceContextProvider;

  DefaultSentryMetrics({
    required this._captureMetricCallback,
    required this._clockProvider,
    required this._traceContextProvider,
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

    final (:traceId, :spanId) = _traceContextProvider();
    final metric = SentryCounterMetric(
      timestamp: _clockProvider(),
      name: name,
      value: value,
      spanId: spanId,
      traceId: traceId,
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

    final (:traceId, :spanId) = _traceContextProvider();
    final metric = SentryGaugeMetric(
      timestamp: _clockProvider(),
      name: name,
      value: value,
      unit: unit,
      spanId: spanId,
      traceId: traceId,
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

    final (:traceId, :spanId) = _traceContextProvider();
    final metric = SentryDistributionMetric(
      timestamp: _clockProvider(),
      name: name,
      value: value,
      unit: unit,
      spanId: spanId,
      traceId: traceId,
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
