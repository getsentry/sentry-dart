import 'dart:async';

import '../../../sentry.dart';
import '../span/sentry_span_v2.dart';
import 'attributes_provider.dart';

class SpanSegmentTelemetryAttributesProvider
    implements TelemetryAttributesProvider {
  SpanSegmentTelemetryAttributesProvider();

  @override
  FutureOr<Map<String, SentryAttribute>> attributes(Object telemetryItem) {
    if (telemetryItem is! RecordingSentrySpanV2) {
      return {};
    }

    return {
      SemanticAttributesConstants.sentrySegmentId:
          SentryAttribute.string(telemetryItem.segmentSpan.spanId.toString()),
      SemanticAttributesConstants.sentrySegmentName:
          SentryAttribute.string(telemetryItem.segmentSpan.name),
    };
  }
}
