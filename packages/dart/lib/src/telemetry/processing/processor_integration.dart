import '../../../sentry.dart';
import 'in_memory_buffer.dart';
import 'processor.dart';

class DefaultTelemetryProcessorIntegration extends Integration<SentryOptions> {
  static const integrationName = 'DefaultTelemetryProcessor';

  @override
  void call(Hub hub, SentryOptions options) {
    if (options.telemetryProcessor is! NoOpTelemetryProcessor) {
      options.log(
        SentryLevel.debug,
        '$integrationName: ${options.telemetryProcessor.runtimeType} already set, skipping',
      );
      return;
    }

    options.telemetryProcessor = DefaultTelemetryProcessor(options.log,
        logBuffer: _createLogBuffer(options));

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
}
