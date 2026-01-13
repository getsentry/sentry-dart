import 'package:meta/meta.dart';

import '../../../sentry.dart';
import 'common_attributes_provider.dart';
import 'scope_attributes_provider.dart';
import 'span_segment_attributes_provider.dart';

/// Integration that sets up the telemetry enrichment pipeline.
@internal
class CommonTelemetryEnricherIntegration extends Integration<SentryOptions> {
  static const integrationName = 'DartTelemetryEnricher';

  @override
  void call(Hub hub, SentryOptions options) {
    final pipeline = options.telemetryEnricher;

    final commonAttributesProvider =
        CommonTelemetryAttributesProvider(hub.scope, options);
    pipeline.registerSpanAttributesProvider(commonAttributesProvider);
    pipeline.registerLogAttributesProvider(commonAttributesProvider);

    final spanSegmentAttributesProvider =
        SpanSegmentTelemetryAttributesProvider();
    pipeline.registerSpanAttributesProvider(spanSegmentAttributesProvider);

    // Scope may contain user set attributes so we want to make sure it's executed later
    final scopeAttributesProvider = ScopeTelemetryAttributesProvider(hub.scope);
    pipeline.registerSpanAttributesProvider(scopeAttributesProvider);
    pipeline.registerLogAttributesProvider(scopeAttributesProvider);

    options.sdk.addIntegration(integrationName);
  }
}
