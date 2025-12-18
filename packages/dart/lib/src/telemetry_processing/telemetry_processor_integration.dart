import '../hub.dart';
import '../integration.dart';
import '../sentry_options.dart';
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
      traceContextHeaderFactory: (span) =>
          hub.scope.propagationContext.getOrCreateTraceContextHeader(
        release: options.release,
        environment: options.environment,
        publicKey: options.parsedDsn.publicKey,
        tracesSampleRate: options.tracesSampleRate,
        segmentName: span.segmentSpan.name,
      ),
      sdkVersion: options.sdk,
      dsn: options.dsn,
    );
    final spanBuffer = InMemoryTelemetryBuffer(
      logger: options.log,
      envelopeBuilder: spanEnvelopeBuilder,
      transport: options.transport,
    );

    options.telemetryProcessor = DefaultTelemetryProcessor(options.log,
        logBuffer: logBuffer, spanBuffer: spanBuffer);

    options.sdk.addIntegration(integrationName);
  }
}
