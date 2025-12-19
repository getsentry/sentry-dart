import 'package:sentry/sentry.dart';
import 'package:sentry/src/spans_v2/sentry_span_v2.dart';

/// Factory for creating [RecordingSentrySpanV2] instances in tests.
///
/// This provides a centralized way to create test spans with sensible defaults,
/// reducing duplication across test files.
class MockSentrySpanV2Factory {
  final SentryOptions options;

  /// Optional trace context to use for all spans created by this factory.
  final SentryTraceContextHeader? traceContext;

  MockSentrySpanV2Factory(this.options, {this.traceContext});

  /// Creates a [RecordingSentrySpanV2] for testing.
  ///
  /// - [name]: The span name (defaults to 'test-span' for root spans, 'child-span' for child spans)
  /// - [parent]: Optional parent span (if provided, creates a child span)
  /// - [traceId]: Optional trace ID (defaults to a new random ID)
  /// - [onSpanEnded]: Optional callback when span ends (defaults to no-op)
  RecordingSentrySpanV2 createSpan({
    String? name,
    RecordingSentrySpanV2? parent,
    SentryId? traceId,
    void Function(RecordingSentrySpanV2)? onSpanEnded,
  }) {
    return RecordingSentrySpanV2(
      name: name ?? (parent == null ? 'test-span' : 'child-span'),
      parentSpan: parent,
      defaultTraceId: traceId ?? SentryId.newId(),
      onSpanEnded: onSpanEnded ?? (_) {},
      dscFactory: traceContext != null
          ? (_) => traceContext!
          : (_) => SentryTraceContextHeader(SentryId.newId(), 'test-key'),
      log: options.log,
      clock: options.clock,
    );
  }
}

