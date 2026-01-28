import 'package:meta/meta.dart';

import '../../protocol/span_status.dart';

/// Wrapper for span instrumentation for integrations such as Drift, Hive, etc.
///
/// This interface provides a unified, implementation-agnostic way to wrap
/// operations with spans. It does not expose any span types, allowing
/// integration packages to instrument code without coupling to a specific
/// tracing implementation.
@internal
abstract class SpanWrapper {
  Future<T> wrapAsync<T>({
    required String operation,
    required String description,
    required Future<T> Function() execute,
    required String loggerName,
    String? origin,
    Map<String, Object>? attributes,
    Object? parentSpan,
  });

  T wrapSync<T>({
    required String operation,
    required String description,
    required T Function() execute,
    required String loggerName,
    String? origin,
    Map<String, Object>? attributes,
    Object? parentSpan,
  });

  /// Starts a child span and returns an opaque handle.
  ///
  /// Use this for operations that need to manage span lifecycle manually,
  /// such as transactions with nested child operations. The returned handle
  /// can be passed as [parentSpan] to other wrapper methods.
  ///
  /// Returns null if no parent span is available.
  Object? startSpan({
    required String operation,
    required String description,
    String? origin,
    Map<String, Object>? attributes,
    Object? parentSpan,
  });

  /// Finishes a span that was started with [startSpan].
  Future<void> finishSpan(
    Object? span, {
    SpanStatus? status,
    Object? throwable,
  });
}
