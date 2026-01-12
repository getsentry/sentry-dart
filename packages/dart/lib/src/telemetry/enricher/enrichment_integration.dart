import 'package:meta/meta.dart';

import '../../../sentry.dart';
import 'common_attribute_provider.dart';
import 'enrichment_pipeline.dart';

/// Integration that sets up the telemetry enrichment pipeline.
@internal
class DefaultTelemetryEnrichmentIntegration extends Integration<SentryOptions> {
  static const integrationName = 'TelemetryEnrichment';

  @override
  void call(Hub hub, SentryOptions options) {
    final registry = options.enricherRegistry;

    registry.registerProvider(CommonAttributeProvider(hub.scope, options));

    if (options.telemetryEnrichmentPipeline is NoOpEnrichmentPipeline) {
      options.telemetryEnrichmentPipeline =
          DefaultTelemetryEnrichmentPipeline(registry);
    }

    options.sdk.addIntegration(integrationName);
  }
}
