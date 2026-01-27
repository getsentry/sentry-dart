import 'package:meta/meta.dart';

import '../../../protocol/span_status.dart';
import '../span_wrapper.dart';

/// A recorded span operation for testing purposes.
///
/// This captures the parameters passed to [SpanWrapper] methods without
/// depending on any specific span implementation.
@visibleForTesting
class RecordedSpanCall {
  /// The span operation name (e.g., 'db.sql.query').
  final String operation;

  /// The span description.
  final String description;

  /// The span origin identifier.
  final String? origin;

  /// The attributes attached to the span.
  final Map<String, Object>? attributes;

  /// The parent span object, if any.
  final Object? parentSpan;

  /// Whether a parent span is required.
  final bool requireParent;

  /// The result of the operation.
  final Object? result;

  /// Whether the operation was async.
  final bool isAsync;

  RecordedSpanCall({
    required this.operation,
    required this.description,
    this.origin,
    this.attributes,
    this.parentSpan,
    this.requireParent = true,
    this.result,
    required this.isAsync,
  });
}

/// A [SpanWrapper] implementation that records all calls for testing.
///
/// This allows tests to verify that integrations call the wrapper with
/// correct parameters without depending on any specific span implementation
/// (like [ISentrySpan] or [SentrySpan]).
///
/// Example usage:
/// ```dart
/// final recorder = RecordingSpanWrapper();
/// final interceptor = SentryQueryInterceptor(
///   databaseName: 'test',
///   hub: hub,
///   spanWrapper: recorder,
/// );
///
/// // ... perform operations ...
///
/// expect(recorder.calls.length, 1);
/// expect(recorder.calls.first.operation, 'db.sql.query');
/// ```
@visibleForTesting
class RecordingSpanWrapper extends SpanWrapper {
  /// All recorded span calls.
  final List<RecordedSpanCall> calls = [];

  @override
  Future<T> wrapAsync<T>({
    required String operation,
    required String description,
    required Future<T> Function() execute,
    String? origin,
    Map<String, Object>? attributes,
    SpanStatus Function(T result)? deriveStatus,
    Object? parentSpan,
    bool requireParent = true,
  }) async {
    final result = await execute();
    calls.add(
      RecordedSpanCall(
        operation: operation,
        description: description,
        origin: origin,
        attributes: attributes != null ? Map.from(attributes) : null,
        parentSpan: parentSpan,
        requireParent: requireParent,
        result: result,
        isAsync: true,
      ),
    );
    return result;
  }

  @override
  T wrapSync<T>({
    required String operation,
    required String description,
    required T Function() execute,
    String? origin,
    Map<String, Object>? attributes,
    SpanStatus Function(T result)? deriveStatus,
    Object? parentSpan,
    bool requireParent = true,
  }) {
    final result = execute();
    calls.add(
      RecordedSpanCall(
        operation: operation,
        description: description,
        origin: origin,
        attributes: attributes != null ? Map.from(attributes) : null,
        parentSpan: parentSpan,
        requireParent: requireParent,
        result: result,
        isAsync: false,
      ),
    );
    return result;
  }

  /// Returns calls matching the given operation.
  List<RecordedSpanCall> callsWithOperation(String operation) =>
      calls.where((c) => c.operation == operation).toList();

  /// Returns calls matching the given description.
  List<RecordedSpanCall> callsWithDescription(String description) =>
      calls.where((c) => c.description == description).toList();

  /// Clears all recorded calls.
  void clear() => calls.clear();
}
