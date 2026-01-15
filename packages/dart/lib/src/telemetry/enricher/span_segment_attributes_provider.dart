import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../span/sentry_span_v2.dart';

/// Provides segment metadata for spans.
///
/// Only contributes attributes to [RecordingSentrySpanV2] items,
/// adding segment ID and name to each span.
@internal
final class SpanSegmentTelemetryAttributesProvider
    implements TelemetryAttributesProvider {
  @override
  Future<Map<String, SentryAttribute>> attributes(Object item, {Scope? scope}) {
    if (item is! RecordingSentrySpanV2) {
      return Future.value({});
    }

    final attributes = <String, SentryAttribute>{};

    attributes[SemanticAttributesConstants.sentrySegmentId] =
        SentryAttribute.string(item.segmentSpan.spanId.toString());
    attributes[SemanticAttributesConstants.sentrySegmentName] =
        SentryAttribute.string(item.segmentSpan.name);

    return Future.value(attributes);
  }
}
