import 'package:meta/meta.dart';

import '../../../sentry.dart';

/// Factory for creating [InstrumentationSpan] instances.
/// Configure via [SentryOptions.spanFactory].
@internal
abstract class InstrumentationSpanFactory {
  /// Returns `null` if span creation fails or if the parent span is no-op.
  InstrumentationSpan? createSpan({
    required InstrumentationSpan parentSpan,
    required String operation,
    String? description,
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
  }) {
    if (parentSpan is LegacyInstrumentationSpan) {
      final parentSpanRef = parentSpan.spanReference;
      if (parentSpanRef is NoOpSentrySpan) return null;

      final child = parentSpanRef.startChild(
        operation,
        description: description,
      );

      if (child is NoOpSentrySpan) return null;
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
  }) {
    if (parentSpan is StreamingInstrumentationSpan) {
      final parentSpanRef = parentSpan.spanReference;
      if (parentSpanRef is NoOpSentrySpanV2) return null;

      final childSpan = _hub.startInactiveSpan(description ?? operation,
          parentSpan: parentSpanRef);

      if (childSpan is NoOpSentrySpanV2) return null;

      childSpan.setAttribute(
        SemanticAttributesConstants.sentryOp,
        SentryAttribute.string(operation),
      );

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
