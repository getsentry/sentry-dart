import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../../utils/internal_logger.dart';
import '../default_attributes.dart';
import 'sentry_span_v2.dart';

@internal
class SpanCapturePipeline {
  final SentryOptions _options;

  SpanCapturePipeline(this._options);

  Future<void> captureSpan(SentrySpanV2 span, {Scope? scope}) async {
    if (_options.traceLifecycle == SentryTraceLifecycle.static) {
      internalLogger.warning(
        'captureSpan: invalid usage with traceLifecycle static, skipping capture.',
      );
      return;
    }

    switch (span) {
      case UnsetSentrySpanV2():
        internalLogger.warning(
          'captureSpan: span is in an invalid state $UnsetSentrySpanV2.',
        );
      case NoOpSentrySpanV2():
        return;
      case RecordingSentrySpanV2 span:
        try {
          if (scope != null) {
            span.addAttributesIfAbsent(scope.attributes);
          }

          await _options.lifecycleRegistry
              .dispatchCallback<OnProcessSpan>(OnProcessSpan(span));

          span.addAttributesIfAbsent(defaultAttributes(_options, scope: scope));
          span.addAttributesIfAbsent({
            SemanticAttributesConstants.sentrySegmentName:
                SentryAttribute.string(span.segmentSpan.name),
            SemanticAttributesConstants.sentrySegmentId:
                SentryAttribute.string(span.segmentSpan.spanId.toString()),
          });

          await _options.beforeSendSpan?.call(span);

          _options.telemetryProcessor.addSpan(span);
        } catch (error, stackTrace) {
          internalLogger.error('Error while capturing span',
              error: error, stackTrace: stackTrace);
          if (_options.automatedTestMode) {
            rethrow;
          }
        }
    }
  }

  // TODO(next-pr): client report
}
