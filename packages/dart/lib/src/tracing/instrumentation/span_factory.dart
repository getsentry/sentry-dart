import 'package:meta/meta.dart';

import '../../hub.dart';
import '../../noop_sentry_span.dart';
import 'instrumentation_span.dart';

/// Factory for creating [InstrumentationSpan] instances.
///
/// This abstraction allows the underlying span implementation to be swapped
/// (e.g., from [ISentrySpan] to SentrySpanV2) without changing instrumentation code.
///
/// Configure via [SentryOptions.spanFactory].
@internal
abstract class InstrumentationSpanFactory {
  /// Creates a child span from a parent.
  ///
  /// Returns `null` if [parent] is `null` or if the span could not be created
  /// (e.g., max spans limit reached).
  InstrumentationSpan? createChildSpan(
    InstrumentationSpan? parent,
    String operation, {
    String? description,
    DateTime? startTimestamp,
  });

  /// Gets the current active span from the hub's scope.
  ///
  /// Returns `null` if there is no active span or if tracing is disabled.
  InstrumentationSpan? getCurrentSpan(Hub hub);
}

/// Default implementation of [InstrumentationSpanFactory] using [ISentrySpan].
///
/// This is the legacy implementation that wraps the existing Sentry span API.
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

    // Access underlying ISentrySpan to call startChild
    if (parent is LegacyInstrumentationSpan) {
      final child = parent.underlyingSpan.startChild(
        operation,
        description: description,
        startTimestamp: startTimestamp,
      );

      if (child is NoOpSentrySpan) return null;
      return LegacyInstrumentationSpan(child);
    }

    // If parent is not a LegacyInstrumentationSpan, we can't create a child
    // This shouldn't happen with the default factory, but handle gracefully
    return null;
  }

  @override
  InstrumentationSpan? getCurrentSpan(Hub hub) {
    final span = hub.getSpan();
    if (span == null || span is NoOpSentrySpan) return null;
    return LegacyInstrumentationSpan(span);
  }
}
