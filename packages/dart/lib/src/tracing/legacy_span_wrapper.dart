// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry.dart';

/// [SpanWrapper] implementation using Sentry's legacy transaction-based tracing.
///
/// This implementation uses [ISentrySpan] and [SentryTracer] for span operations.
/// It creates child spans under the current active span from the hub.
///
/// Integration packages should not instantiate this directly. Instead, access
/// it via [SentryOptions.spanWrapper].
@internal
class LegacySpanWrapper implements SpanWrapper {
  final Hub _hub;

  LegacySpanWrapper({required Hub hub}) : _hub = hub;

  /// Resolves the parent span from the provided [parentSpan] or falls back to hub.
  ///
  /// If [parentSpan] is provided and is an [ISentrySpan], it's used directly.
  /// Otherwise, falls back to the hub's active span.
  ISentrySpan? _resolveParent(Object? parentSpan) {
    if (parentSpan is ISentrySpan) {
      return parentSpan;
    }
    return _hub.getSpan();
  }

  @override
  Future<T> wrapAsync<T>({
    required String operation,
    required String description,
    required Future<T> Function() execute,
    String? origin,
    Map<String, Object>? attributes,
    TracingStatus Function(T result)? deriveStatus,
    Object? parentSpan,
  }) async {
    final parent = _resolveParent(parentSpan);
    if (parent == null) {
      return execute();
    }

    final span = parent.startChild(operation, description: description);
    _configureSpan(span, origin: origin, attributes: attributes);

    try {
      final result = await execute();
      span.status = _toSpanStatus(deriveStatus?.call(result) ?? TracingStatus.ok);
      return result;
    } catch (exception) {
      span.throwable = exception;
      span.status = SpanStatus.internalError();
      rethrow;
    } finally {
      await span.finish();
    }
  }

  @override
  T wrapSync<T>({
    required String operation,
    required String description,
    required T Function() execute,
    String? origin,
    Map<String, Object>? attributes,
    TracingStatus Function(T result)? deriveStatus,
    Object? parentSpan,
  }) {
    final parent = _resolveParent(parentSpan);
    if (parent == null) {
      return execute();
    }

    final span = parent.startChild(operation, description: description);
    _configureSpan(span, origin: origin, attributes: attributes);

    try {
      final result = execute();
      span.status = _toSpanStatus(deriveStatus?.call(result) ?? TracingStatus.ok);
      return result;
    } catch (exception) {
      span.throwable = exception;
      span.status = SpanStatus.internalError();
      rethrow;
    } finally {
      span.finish();
    }
  }

  @override
  Future<T> wrapAsyncOrStartTransaction<T>({
    required String operation,
    required String description,
    required Future<T> Function() execute,
    String? origin,
    Map<String, Object>? attributes,
    TracingStatus Function(T result)? deriveStatus,
  }) async {
    final existingSpan = _hub.getSpan();

    if (existingSpan != null) {
      return wrapAsync(
        operation: operation,
        description: description,
        execute: execute,
        origin: origin,
        attributes: attributes,
        deriveStatus: deriveStatus,
      );
    }

    // Start a new transaction
    final transaction = _hub.startTransaction(
      operation,
      description,
      bindToScope: true,
    );
    _configureSpan(transaction, origin: origin, attributes: attributes);

    try {
      final result = await execute();
      transaction.status =
          _toSpanStatus(deriveStatus?.call(result) ?? TracingStatus.ok);
      return result;
    } catch (exception) {
      transaction.throwable = exception;
      transaction.status = SpanStatus.internalError();
      rethrow;
    } finally {
      await transaction.finish();
    }
  }

  void _configureSpan(
    ISentrySpan span, {
    String? origin,
    Map<String, Object>? attributes,
  }) {
    if (origin != null) {
      span.origin = origin;
    }
    attributes?.forEach((key, value) => span.setData(key, value));
  }

  /// Converts [TracingStatus] to legacy [SpanStatus].
  SpanStatus _toSpanStatus(TracingStatus status) {
    return switch (status) {
      TracingStatus.ok => SpanStatus.ok(),
      TracingStatus.cancelled => SpanStatus.cancelled(),
      TracingStatus.unknown => SpanStatus.unknownError(),
      TracingStatus.invalidArgument => SpanStatus.invalidArgument(),
      TracingStatus.deadlineExceeded => SpanStatus.deadlineExceeded(),
      TracingStatus.notFound => SpanStatus.notFound(),
      TracingStatus.alreadyExists => SpanStatus.alreadyExists(),
      TracingStatus.permissionDenied => SpanStatus.permissionDenied(),
      TracingStatus.resourceExhausted => SpanStatus.resourceExhausted(),
      TracingStatus.failedPrecondition => SpanStatus.failedPrecondition(),
      TracingStatus.aborted => SpanStatus.aborted(),
      TracingStatus.outOfRange => SpanStatus.outOfRange(),
      TracingStatus.unimplemented => SpanStatus.unimplemented(),
      TracingStatus.internalError => SpanStatus.internalError(),
      TracingStatus.unavailable => SpanStatus.unavailable(),
      TracingStatus.dataLoss => SpanStatus.dataLoss(),
      TracingStatus.unauthenticated => SpanStatus.unauthenticated(),
    };
  }
}
