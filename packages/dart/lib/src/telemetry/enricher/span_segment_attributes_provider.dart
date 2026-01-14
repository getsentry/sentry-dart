import 'dart:async';

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
  bool supports(Object item) {
    return item is RecordingSentrySpanV2;
  }

  @override
  FutureOr<Map<String, SentryAttribute>> attributes(Object item,
      {Scope? scope}) {
    final attributes = <String, SentryAttribute>{};
    final span = item as RecordingSentrySpanV2;

    attributes[SemanticAttributesConstants.sentrySegmentId] =
        SentryAttribute.string(span.segmentSpan.spanId.toString());
    attributes[SemanticAttributesConstants.sentrySegmentName] =
        SentryAttribute.string(span.segmentSpan.name);

    return attributes;
  }
}
