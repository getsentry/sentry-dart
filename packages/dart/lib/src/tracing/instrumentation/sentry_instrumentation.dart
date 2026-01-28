import 'package:meta/meta.dart';

import '../../hub.dart';
import '../../hub_adapter.dart';
import '../../protocol.dart';
import 'instrumentation_span.dart';
import 'span_factory.dart';

/// Helper class for instrumenting operations with Sentry spans.
///
/// This class provides a unified API for creating and managing spans across
/// different Sentry packages. It abstracts away the underlying span implementation,
/// allowing the tracing backend to be swapped (e.g., to SentrySpanV2).
@internal
class SentryInstrumentation {
  final Hub _hub;
  final String _origin;
  final InstrumentationSpanFactory _factory;

  SentryInstrumentation(
    Hub? hub,
    this._origin, {
    InstrumentationSpanFactory? factory,
  })  : _hub = hub ?? HubAdapter(),
        _factory = factory ?? LegacyInstrumentationSpanFactory();

  /// Gets the current active span from the hub's scope.
  ///
  /// Returns `null` if there is no active span or tracing is disabled.
  InstrumentationSpan? getCurrentSpan() => _factory.getCurrentSpan(_hub);

  /// Creates a child span from a parent.
  ///
  /// If [parent] is `null`, uses the current span from the hub's scope.
  /// Returns `null` if no parent is available or span creation fails.
  InstrumentationSpan? createChildSpan({
    required String operation,
    String? description,
    InstrumentationSpan? parent,
    DateTime? startTimestamp,
  }) {
    final parentSpan = parent ?? getCurrentSpan();
    return _factory.createChildSpan(
      parentSpan,
      operation,
      description: description,
      startTimestamp: startTimestamp,
    );
  }

  /// Wraps an async operation in a span.
  ///
  /// Creates a child span, executes the operation, and handles status/error
  /// tracking automatically. The span is finished when the operation completes.
  ///
  /// If no parent span is available, executes the operation without tracing.
  Future<T> asyncWrapInSpan<T>({
    required String operation,
    required String description,
    required Future<T> Function() execute,
    Map<String, dynamic>? data,
    InstrumentationSpan? parent,
  }) async {
    final span = createChildSpan(
      operation: operation,
      description: description,
      parent: parent,
    );

    if (span == null) {
      return execute();
    }

    span.origin = _origin;
    data?.forEach((key, value) => span.setData(key, value));

    try {
      final result = await execute();
      span.status = SpanStatus.ok();
      return result;
    } catch (exception) {
      span.throwable = exception;
      span.status = SpanStatus.internalError();
      rethrow;
    } finally {
      await span.finish();
    }
  }

  /// Wraps a synchronous operation in a span.
  ///
  /// Creates a child span, executes the operation, and handles status/error
  /// tracking automatically. The span is finished when the operation completes.
  ///
  /// If no parent span is available, executes the operation without tracing.
  T syncWrapInSpan<T>({
    required String operation,
    required String description,
    required T Function() execute,
    Map<String, dynamic>? data,
    InstrumentationSpan? parent,
  }) {
    final span = createChildSpan(
      operation: operation,
      description: description,
      parent: parent,
    );

    if (span == null) {
      return execute();
    }

    span.origin = _origin;
    span.setData('sync', true);
    data?.forEach((key, value) => span.setData(key, value));

    try {
      final result = execute();
      span.status = SpanStatus.ok();
      return result;
    } catch (exception) {
      span.throwable = exception;
      span.status = SpanStatus.internalError();
      rethrow;
    } finally {
      span.finish();
    }
  }
}
