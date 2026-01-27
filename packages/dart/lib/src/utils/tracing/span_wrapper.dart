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
    SpanStatus Function(T result)? deriveStatus,
    Object? parentSpan,
  });

  T wrapSync<T>({
    required String operation,
    required String description,
    required T Function() execute,
    required String loggerName,
    String? origin,
    Map<String, Object>? attributes,
    SpanStatus Function(T result)? deriveStatus,
    Object? parentSpan,
  });
}
