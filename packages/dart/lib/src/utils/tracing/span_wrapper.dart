import 'package:meta/meta.dart';

import '../../protocol/span_status.dart';

/// Wrapper for span instrumentation for integrations such as Drift, Hive, etc.
///
/// This interface provides a unified, implementation-agnostic way to wrap
/// operations with spans. It does not expose any span types, allowing
/// integration packages to instrument code without coupling to a specific
/// tracing implementation.
///
/// The implementation (e.g., [LegacySpanWrapper]) handles the actual span
/// creation using the configured tracing backend.
///
/// Example usage:
/// ```dart
/// final wrapper = hub.options.spanWrapper;
/// final result = await wrapper.wrapAsync(
///   operation: 'db.sql.query',
///   description: 'SELECT * FROM users',
///   execute: () => database.query('SELECT * FROM users'),
///   origin: 'auto.db.my_integration',
///   attributes: {'db.system': 'sqlite'},
/// );
/// ```
@internal
abstract class SpanWrapper {
  /// Wraps an asynchronous operation with a span.
  ///
  /// Creates a child span under the current active span, executes [execute],
  /// and finishes the span when complete.
  ///
  /// Parameters:
  /// - [operation]: The span operation name (e.g., 'db.sql.query', 'http.client').
  /// - [description]: A description of the operation (e.g., the SQL query, URL).
  /// - [execute]: The async function to execute within the span.
  /// - [origin]: Optional origin identifier for the span.
  /// - [attributes]: Optional attributes to attach to the span.
  /// - [deriveStatus]: Optional function to derive span status from the result.
  ///   If not provided, defaults to [SpanStatus.ok] on success.
  /// - [parentSpan]: Optional parent span to use instead of the hub's active span.
  ///   This is useful for integrations that manage their own span hierarchy
  ///   (e.g., nested database transactions).
  /// - [requireParent]: If true (default), only creates a span if a parent exists.
  ///   If false and no parent exists, starts a new transaction instead.
  ///
  /// Returns the result of [execute].
  ///
  /// On exception, the span is marked with [SpanStatus.internalError] and
  /// the exception is recorded before being rethrown.
  Future<T> wrapAsync<T>({
    required String operation,
    required String description,
    required Future<T> Function() execute,
    String? origin,
    Map<String, Object>? attributes,
    SpanStatus Function(T result)? deriveStatus,
    Object? parentSpan,
    bool requireParent = true,
  });

  /// Wraps a synchronous operation with a span.
  ///
  /// Creates a child span under the current active span, executes [execute],
  /// and finishes the span when complete.
  ///
  /// Parameters:
  /// - [operation]: The span operation name (e.g., 'db.sql.query', 'file.read').
  /// - [description]: A description of the operation (e.g., the SQL query, filename).
  /// - [execute]: The sync function to execute within the span.
  /// - [origin]: Optional origin identifier for the span.
  /// - [attributes]: Optional attributes to attach to the span.
  /// - [deriveStatus]: Optional function to derive span status from the result.
  ///   If not provided, defaults to [SpanStatus.ok] on success.
  /// - [parentSpan]: Optional parent span to use instead of the hub's active span.
  ///   This is useful for integrations that manage their own span hierarchy
  ///   (e.g., nested database transactions).
  /// - [requireParent]: If true (default), only creates a span if a parent exists.
  ///   If false and no parent exists, starts a new transaction instead.
  ///
  /// Returns the result of [execute].
  ///
  /// On exception, the span is marked with [SpanStatus.internalError] and
  /// the exception is recorded before being rethrown.
  T wrapSync<T>({
    required String operation,
    required String description,
    required T Function() execute,
    String? origin,
    Map<String, Object>? attributes,
    SpanStatus Function(T result)? deriveStatus,
    Object? parentSpan,
    bool requireParent = true,
  });
}
