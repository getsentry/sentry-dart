import '../../sentry.dart';
import '../spans_v2/sentry_span_v2.dart';
import 'envelope_builder.dart';
import 'telemetry_buffer.dart';
import 'telemetry_processor.dart';

/// Integration that sets up the default telemetry processor.
///
/// This integration runs after the Hub is initialized, providing access to
/// the Hub and Scope for trace context extraction.
class DefaultTelemetryProcessorIntegration extends Integration<SentryOptions> {
  static const integrationName = 'DefaultTelemetryProcessor';

  @override
  void call(Hub hub, SentryOptions options) {
    if (options.telemetryProcessor is! NoOpTelemetryProcessor) {
      return;
    }

    final logEnvelopeBuilder = LogEnvelopeBuilder(options.sdk);
    final logBuffer = InMemoryTelemetryBuffer(
      logger: options.log,
      envelopeBuilder: logEnvelopeBuilder,
      transport: options.transport,
    );

    final spanEnvelopeBuilder = SpanEnvelopeBuilder(
      traceContextHeaderFactory: (span) => span.getOrCreateDsc(),
      sdkVersion: options.sdk,
      dsn: options.dsn,
    );
    final spanBuffer = InMemoryTelemetryBuffer<RecordingSentrySpanV2>(
      logger: options.log,
      envelopeBuilder: spanEnvelopeBuilder,
      transport: options.transport,
    );

    options.telemetryProcessor = DefaultTelemetryProcessor(options.log,
        logBuffer: logBuffer, spanBuffer: spanBuffer);

    options.sdk.addIntegration(integrationName);
  }
}
