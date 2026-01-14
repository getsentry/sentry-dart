import 'package:meta/meta.dart';

import '../../../sentry.dart';
import 'common_attributes_provider.dart';
import 'span_segment_attributes_provider.dart';

/// Sets up common telemetry enrichment.
@internal
final class CommonTelemetryEnricherIntegration
    extends Integration<SentryOptions> {
  static const integrationName = 'CommonTelemetryEnricher';

  @override
  void call(Hub hub, SentryOptions options) {
    final enricher = options.globalTelemetryEnricher;

    final commonProvider = CommonTelemetryAttributesProvider(options);
    enricher.registerAttributesProvider(commonProvider);

    final spanSegmentProvider = SpanSegmentTelemetryAttributesProvider();
    enricher.registerAttributesProvider(spanSegmentProvider);

    options.sdk.addIntegration(integrationName);
  }
}
