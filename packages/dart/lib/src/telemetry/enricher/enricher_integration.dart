import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../../utils/_io_get_sentry_operating_system.dart';
import 'common_attributes_provider.dart';
import 'span_segment_attributes_provider.dart';

/// Sets up core telemetry attributes enrichment that must be applied to telemetries.
@internal
final class CoreTelemetryAttributesIntegration
    extends Integration<SentryOptions> {
  static const integrationName = 'CoreTelemetryAttributes';

  @override
  void call(Hub hub, SentryOptions options) {
    options.telemetryEnricher.addAttributesProvider(
        CommonTelemetryAttributesProvider(options, getSentryOperatingSystem()));
    options.telemetryEnricher
        .addAttributesProvider(SpanSegmentTelemetryAttributesProvider());

    options.sdk.addIntegration(integrationName);
  }
}
