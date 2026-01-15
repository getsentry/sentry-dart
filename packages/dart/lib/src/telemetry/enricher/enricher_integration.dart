import 'package:meta/meta.dart';

import '../../../sentry.dart';
import 'common_attributes_provider.dart';
import 'span_segment_attributes_provider.dart';

/// Sets up common telemetry enrichment.
@internal
final class CoreTelemetryAttributesIntegration
    extends Integration<SentryOptions> {
  static const integrationName = 'CoreTelemetryAttributes';

  @override
  void call(Hub hub, SentryOptions options) {
    options.telemetryEnricher
        .addAttributesProvider(CommonTelemetryAttributesProvider(options));
    options.telemetryEnricher
        .addAttributesProvider(SpanSegmentTelemetryAttributesProvider());

    options.sdk.addIntegration(integrationName);
  }
}
