import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../../utils/internal_logger.dart';
import 'in_memory_buffer.dart';
import 'processor.dart';

/// Integration that sets up in-memory telemetry processing for Dart.
///
/// This is the standard processor when no other implementation is provided.
/// It buffers and batches telemetry data in memory before export.
class InMemoryTelemetryProcessorIntegration extends Integration<SentryOptions> {
  static const integrationName = 'InMemoryTelemetryProcessor';

  @visibleForTesting
  final GroupKeyExtractor<RecordingSentrySpanV2> spanGroupKeyExtractor =
      (RecordingSentrySpanV2 item) =>
          '${item.traceId}-${item.segmentSpan.spanId}';

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
      spanBuffer: _createSpanBuffer(options),
      metricBuffer: _createMetricBuffer(options),
    );

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

  GroupedInMemoryTelemetryBuffer<RecordingSentrySpanV2> _createSpanBuffer(
          SentryOptions options) =>
      GroupedInMemoryTelemetryBuffer(
          encoder: (RecordingSentrySpanV2 item) =>
              utf8JsonEncoder.convert(item.toJson()),
          onFlush: (items) {
            final futures = items.values.map((itemData) {
              final dsc = itemData.$2.resolveDsc();
              final envelope = SentryEnvelope.fromSpansData(
                  itemData.$1, options.sdk,
                  traceContext: dsc);
              return options.transport.send(envelope);
            }).toList();
            if (futures.isEmpty) return null;
            return Future.wait(futures).then((_) {});
          },
          groupKeyExtractor: spanGroupKeyExtractor);

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
