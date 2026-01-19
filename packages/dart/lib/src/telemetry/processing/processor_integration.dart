import '../../../sentry.dart';
import '../../utils/internal_logger.dart';
import '../metric/metric.dart';
import 'in_memory_buffer.dart';
import 'processor.dart';

/// Integration that sets up in-memory telemetry processing for Dart.
///
/// This is the standard processor when no other implementation is provided.
/// It buffers and batches telemetry data in memory before export.
class InMemoryTelemetryProcessorIntegration extends Integration<SentryOptions> {
  static const integrationName = 'InMemoryTelemetryProcessor';

  @override
  void call(Hub hub, SentryOptions options) {
    if (options.telemetryProcessor is! NoOpTelemetryProcessor) {
      internalLogger.debug(
        () =>
            '$integrationName: ${options.telemetryProcessor.runtimeType} already set, skipping',
      );
      return;
    }

    options.telemetryProcessor = DefaultTelemetryProcessor(
        logBuffer: _createLogBuffer(options),
        metricBuffer: _createMetricBuffer(options));

    options.sdk.addIntegration(integrationName);
  }

  InMemoryTelemetryBuffer<SentryLog> _createLogBuffer(SentryOptions options) =>
      InMemoryTelemetryBuffer(
          encoder: (SentryLog item) => utf8JsonEncoder.convert(item.toJson()),
          onFlush: (items) {
            final envelope = SentryEnvelope.fromLogsData(
                items.map((item) => item).toList(), options.sdk);
            return options.transport.send(envelope).then((_) {});
          });

  InMemoryTelemetryBuffer<SentryMetric> _createMetricBuffer(
          SentryOptions options) =>
      InMemoryTelemetryBuffer(
          encoder: (SentryMetric item) =>
              utf8JsonEncoder.convert(item.toJson()),
          onFlush: (items) {
            final envelope = SentryEnvelope.fromMetricsData(
                items.map((item) => item).toList(), options.sdk);
            return options.transport.send(envelope).then((_) {});
          });
}
