import 'package:meta/meta.dart';

import '../../../sentry.dart';
import 'common_attributes_provider.dart';
import 'scope_attributes_provider.dart';

/// Integration that sets up the telemetry enrichment pipeline.
@internal
class DartTelemetryEnricherIntegration extends Integration<SentryOptions> {
  static const integrationName = 'DartTelemetryEnricher';

  @override
  void call(Hub hub, SentryOptions options) {
    final pipeline = options.enricherPipeline;

    final commonAttributesProvider =
        CommonTelemetryAttributesProvider(hub.scope, options);
    pipeline.registerSpanAttributeProvider(commonAttributesProvider);
    pipeline.registerLogAttributeProvider(commonAttributesProvider);

    // Scope may contain user set attributes so we want to make sure it's executed later
    final scopeAttributesProvider = ScopeTelemetryAttributesProvider(hub.scope);
    pipeline.registerSpanAttributeProvider(scopeAttributesProvider);
    pipeline.registerLogAttributeProvider(scopeAttributesProvider);

    options.sdk.addIntegration(integrationName);
  }
}
