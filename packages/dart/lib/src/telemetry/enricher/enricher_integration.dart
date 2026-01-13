import 'package:meta/meta.dart';

import '../../../sentry.dart';
import 'common_attributes_provider.dart';
import 'scope_attributes_provider.dart';
import 'span_segment_attributes_provider.dart';

/// Integration that sets up the common enrichment to telemetry.
@internal
class CommonTelemetryEnricherIntegration extends Integration<SentryOptions> {
  static const integrationName = 'CommonTelemetryEnricher';

  @override
  void call(Hub hub, SentryOptions options) {
    final pipeline = options.globalTelemetryEnricher;

    final commonAttributesProvider =
        CommonTelemetryAttributesProvider(hub.scope, options).cachedByKey(() {
      final user = hub.scope.user;
      return (
        userId: user?.id,
        userName: user?.name,
        userEmail: user?.email,
      );
    });
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
