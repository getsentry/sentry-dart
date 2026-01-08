import 'package:meta/meta.dart';

import '../../../sentry.dart';
import 'on_before_capture_span_v2.dart';

/// Integration that enriches V2 spans with span-specific attributes.
@internal
class SpanAttributesEnricherIntegration implements Integration<SentryOptions> {
  static const integrationName = 'SpanAttributesEnricher';

  SentryOptions? _options;

  @override
  void call(Hub hub, SentryOptions options) {
    _options = options;

    if (!options.isTracingEnabled()) {
      options.log(
        SentryLevel.info,
        '$integrationName disabled: tracing is not enabled',
      );
      return;
    }

    options.lifecycleRegistry
        .registerCallback<OnBeforeCaptureSpanV2>(_enrichSpan);

    options.sdk.addIntegration(integrationName);
  }

  @override
  void close() {
    _options?.lifecycleRegistry
        .removeCallback<OnBeforeCaptureSpanV2>(_enrichSpan);
    _options = null;
  }

  void _enrichSpan(OnBeforeCaptureSpanV2 event) {
    final span = event.span;
    final attributes = span.attributes;

    // Add segment information
    // The segment span is the local root span of the trace segment
    final segmentSpan = span.segmentSpan;

    if (!attributes.containsKey('sentry.segment.name')) {
      span.setAttribute(
          'sentry.segment.name', SentryAttribute.string(segmentSpan.name));
    }

    if (!attributes.containsKey('sentry.segment.id')) {
      span.setAttribute('sentry.segment.id',
          SentryAttribute.string(segmentSpan.spanId.toString()));
    }
  }
}
