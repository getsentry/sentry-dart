import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../span/sentry_span_v2.dart';
import 'enricher_registry.dart';

/// Base contract for telemetry enrichment pipelines.
///
/// Pipelines delegate to the registry's enrichers which handle
/// provider execution and attribute application.
@internal
abstract class TelemetryEnrichmentPipeline {
  /// Enriches a [SentryLog] using the log enricher.
  FutureOr<void> enrichLog(SentryLog log);

  /// Enriches a [RecordingSentrySpanV2] using the span enricher.
  FutureOr<void> enrichSpan(RecordingSentrySpanV2 span);
}

/// A no-op enrichment pipeline that does nothing.
///
/// Used as the default pipeline before [TelemetryEnrichmentIntegration] runs.
@internal
class NoOpEnrichmentPipeline implements TelemetryEnrichmentPipeline {
  const NoOpEnrichmentPipeline();

  @override
  FutureOr<void> enrichLog(SentryLog log) {}

  @override
  FutureOr<void> enrichSpan(RecordingSentrySpanV2 span) {}
}

/// The default telemetry enrichment pipeline.
///
/// Delegates to the registry's single log and span enrichers,
/// which internally run all registered providers.
@internal
class DefaultTelemetryEnrichmentPipeline
    implements TelemetryEnrichmentPipeline {
  DefaultTelemetryEnrichmentPipeline(this.registry);

  final TelemetryEnricherRegistry registry;

  @override
  FutureOr<void> enrichLog(SentryLog log) => registry.logEnricher.enrich(log);

  @override
  FutureOr<void> enrichSpan(RecordingSentrySpanV2 span) =>
      registry.spanEnricher.enrich(span);
}
