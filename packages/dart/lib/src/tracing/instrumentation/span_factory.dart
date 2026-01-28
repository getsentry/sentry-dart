import 'package:meta/meta.dart';

import '../../hub.dart';
import '../../noop_sentry_span.dart';
import 'instrumentation_span.dart';

/// Factory for creating [InstrumentationSpan] instances.
/// Configure via [SentryOptions.spanFactory].
@internal
abstract class InstrumentationSpanFactory {
  /// Returns `null` if parent is null or span creation fails.
  InstrumentationSpan? createChildSpan(
    InstrumentationSpan? parent,
    String operation, {
    String? description,
    DateTime? startTimestamp,
  });

  /// Returns `null` if no active span or tracing disabled.
  InstrumentationSpan? getSpan(Hub hub);
}

/// Default [InstrumentationSpanFactory] using [ISentrySpan].
@internal
class LegacyInstrumentationSpanFactory implements InstrumentationSpanFactory {
  @override
  InstrumentationSpan? createChildSpan(
    InstrumentationSpan? parent,
    String operation, {
    String? description,
    DateTime? startTimestamp,
  }) {
    if (parent == null) return null;

    if (parent is LegacyInstrumentationSpan) {
      final child = parent.spanReference.startChild(
        operation,
        description: description,
        startTimestamp: startTimestamp,
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
