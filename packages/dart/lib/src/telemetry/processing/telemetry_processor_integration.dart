import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../span/sentry_span_v2.dart';
import 'in_memory_telemetry_buffer.dart';
import 'telemetry_processor.dart';

class DefaultTelemetryProcessorIntegration extends Integration<SentryOptions> {
  static const integrationName = 'DefaultTelemetryProcessor';

  @visibleForTesting
  final GroupKeyExtractor<RecordingSentrySpanV2> spanGroupKeyExtractor =
      (RecordingSentrySpanV2 item) =>
          '${item.traceId}-${item.segmentSpan.spanId}';

  @override
  void call(Hub hub, SentryOptions options) {
    if (options.telemetryProcessor is! NoOpTelemetryProcessor) {
      return;
    }

    options.telemetryProcessor = DefaultTelemetryProcessor(options.log,
        logBuffer: _createLogBuffer(options),
        spanBuffer: _createSpanBuffer(options));

    options.sdk.addIntegration(integrationName);
  }

  InMemoryTelemetryBuffer<SentryLog> _createLogBuffer(SentryOptions options) =>
      InMemoryTelemetryBuffer(
          logger: options.log,
          encoder: (SentryLog item) => utf8JsonEncoder.convert(item.toJson()),
          onFlush: (items) {
            final envelope = SentryEnvelope.fromLogsData(items, options.sdk);
            return options.transport.send(envelope).then((_) {});
          });

  GroupedInMemoryTelemetryBuffer<RecordingSentrySpanV2> _createSpanBuffer(
          SentryOptions options) =>
      GroupedInMemoryTelemetryBuffer(
          logger: options.log,
          encoder: (RecordingSentrySpanV2 item) =>
              utf8JsonEncoder.convert(item.toJson()),
          // TODO(next-pr): add dsc to the envelope for spans
          onFlush: (items) {
            final futures = items.values.map((itemData) {
              final envelope =
                  SentryEnvelope.fromSpansData(itemData, options.sdk);
              return options.transport.send(envelope);
            }).toList();
            if (futures.isEmpty) return null;
            return Future.wait(futures).then((_) {});
          },
          groupKeyExtractor: spanGroupKeyExtractor);
}
