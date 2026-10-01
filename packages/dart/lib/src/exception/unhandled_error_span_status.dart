import '../hub.dart';
import '../protocol.dart';
import '../telemetry/span/sentry_trace_lifecycle.dart';
import '../telemetry/span/streaming/sentry_span_status_v2.dart';

extension UnhandledErrorSpanStatus on Hub {
  /// Marks the active span as errored so it reflects an unhandled error even
  /// when the surrounding code completes normally.
  ///
  /// A streaming span started with `startSpan` is only visible from inside its
  /// callback's zone, so run this in the zone the error originated in. Called
  /// elsewhere, it can only reach the active idle span. A transaction span
  /// keeps a status that was already set.
  void markActiveSpanAsErrored() {
    if (options.traceLifecycle == SentryTraceLifecycle.stream) {
      getActiveSpan()?.status = SentrySpanStatusV2.error;
    } else {
      configureScope(
        (scope) => scope.span?.status ??= const SpanStatus.internalError(),
      );
    }
  }
}
