import 'package:meta/meta.dart';

import '../hub.dart';
import '../integration.dart';
import '../sentry_options.dart';
import 'envelope_builder.dart';
import 'telemetry_buffer.dart';
import 'telemetry_processor.dart';

/// Integration that sets up the telemetry processor.
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

    options.telemetryProcessor = DefaultTelemetryProcessor(
      options.log,
      logBuffer: InMemoryTelemetryBuffer(
        logger: options.log,
        envelopeBuilder: LogEnvelopeBuilder(options.sdk),
        transport: options.transport,
      ),
      spanBuffer: InMemoryTelemetryBuffer(
        logger: options.log,
        envelopeBuilder: SpanEnvelopeBuilder(
          (span) => hub.scope.propagationContext.getOrCreateTraceContextHeader(
            options,
            span.segmentSpan.name,
          ),
          options.sdk,
          options.dsn,
        ),
        transport: options.transport,
      ),
    );

    options.sdk.addIntegration(integrationName);
  }
}
