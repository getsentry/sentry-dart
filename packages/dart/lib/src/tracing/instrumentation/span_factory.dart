import 'package:meta/meta.dart';

import '../../../sentry.dart';
import 'span_attribute_utils.dart';

/// Factory for creating [InstrumentationSpan] instances.
/// Configure via [SentryOptions.spanFactory].
@internal
abstract class InstrumentationSpanFactory {
  /// Returns `null` if span creation fails or if the parent span is no-op.
  InstrumentationSpan? createSpan({
    required InstrumentationSpan parentSpan,
    required String operation,
    String? description,
    String? origin,
    Map<String, dynamic>? data,
    bool isSynchronous = false,
  });

  /// Returns `null` if no active span or tracing disabled.
  InstrumentationSpan? getSpan(Hub hub);
}

/// Default [InstrumentationSpanFactory] using [ISentrySpan].
@internal
class LegacyInstrumentationSpanFactory implements InstrumentationSpanFactory {
  @override
  InstrumentationSpan? createSpan({
    required InstrumentationSpan parentSpan,
    required String operation,
    String? description,
    String? origin,
    Map<String, dynamic>? data,
    bool isSynchronous = false,
  }) {
    if (parentSpan is LegacyInstrumentationSpan) {
      final parentSpanRef = parentSpan.spanReference;
      if (parentSpanRef is NoOpSentrySpan) return null;

      final child = parentSpanRef.startChild(
        operation,
        description: description,
      );

      if (child is NoOpSentrySpan) return null;
      child.origin = origin;
      data?.forEach(child.setData);
      if (isSynchronous) {
        child.setData(synchronousAttributeKey, true);
      }
      return LegacyInstrumentationSpan(child);
    }

    return null;
  }

  @override
  InstrumentationSpan? getSpan(Hub hub) {
    final span = hub.getSpan();
    if (span == null || span is NoOpSentrySpan) return null;
    return LegacyInstrumentationSpan(span);
  }
}

@internal
class StreamingInstrumentationSpanFactory
    implements InstrumentationSpanFactory {
  final Hub _hub;

  StreamingInstrumentationSpanFactory(this._hub);

  @override
  InstrumentationSpan? createSpan({
    required InstrumentationSpan parentSpan,
    required String operation,
    String? description,
    String? origin,
    Map<String, dynamic>? data,
    bool isSynchronous = false,
  }) {
    if (parentSpan is StreamingInstrumentationSpan) {
      final parentSpanRef = parentSpan.spanReference;
      if (parentSpanRef is NoOpSentrySpanV2) return null;

      final attributes = <String, SentryAttribute>{
        SemanticAttributesConstants.sentryOp: SentryAttribute.string(operation),
        if (origin != null)
          SemanticAttributesConstants.sentryOrigin:
              SentryAttribute.string(origin),
        if (isSynchronous) synchronousAttributeKey: SentryAttribute.bool(true),
      };
      data?.forEach((key, value) {
        final attribute = sentryAttributeFromValue(value);
        if (attribute != null) {
          attributes[key] = attribute;
        }
      });

      final childSpan = _hub.startInactiveSpan(
        description ?? operation,
        parentSpan: parentSpanRef,
        attributes: attributes,
      );

      if (childSpan is NoOpSentrySpanV2) return null;

      return StreamingInstrumentationSpan(childSpan);
    }

    return null;
  }

  @override
  InstrumentationSpan? getSpan(Hub hub) {
    final span = hub.getActiveSpan();
    if (span == null) return null;
    return StreamingInstrumentationSpan(span);
  }
}
