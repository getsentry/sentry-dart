import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../span/sentry_span_v2.dart';

/// Provider for span segment metadata.
@internal
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
