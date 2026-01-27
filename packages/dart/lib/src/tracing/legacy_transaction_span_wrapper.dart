// ignore_for_file: invalid_use_of_internal_member

import 'dart:collection';

import 'package:meta/meta.dart';

import '../../sentry.dart';

/// [TransactionSpanWrapper] implementation using Sentry's legacy transaction-based tracing.
@internal
class LegacyTransactionSpanWrapper implements TransactionSpanWrapper {
  final Hub _hub;

  /// Stack of active transaction spans for nested transaction support.
  final ListQueue<ISentrySpan?> _transactionStack = ListQueue();

  LegacyTransactionSpanWrapper({required Hub hub}) : _hub = hub;

  @override
  int get transactionStackSize => _transactionStack.length;

  @override
  ISentrySpan? get currentSpan => _transactionStack.lastOrNull;

  @override
  (T, bool) beginTransaction<T>({
    required String operation,
    required String description,
    required T Function() execute,
    String? origin,
    Map<String, Object>? attributes,
  }) {
    final parent = currentSpan ?? _hub.getSpan();
    if (parent == null) {
      return (execute(), false);
    }

    final span = parent.startChild(operation, description: description);
    if (origin != null) {
      span.origin = origin;
    }
    attributes?.forEach((key, value) => span.setData(key, value));

    try {
      final result = execute();
      span.status = SpanStatus.unknown();
      _transactionStack.add(span);
      return (result, true);
    } catch (exception) {
      span.throwable = exception;
      span.status = SpanStatus.internalError();
      span.finish();
      rethrow;
    }
  }

  @override
  Future<bool> commitTransaction(Future<void> Function() execute) async {
    final span = _transactionStack.lastOrNull;
    if (span == null) {
      return false;
    }

    try {
      await execute();
      span.status = SpanStatus.ok();
      return true;
    } catch (exception) {
      span.throwable = exception;
      span.status = SpanStatus.internalError();
      rethrow;
    } finally {
      await span.finish();
      _transactionStack.removeLast();
    }
  }

  @override
  Future<bool> rollbackTransaction(Future<void> Function() execute) async {
    final span = _transactionStack.lastOrNull;
    if (span == null) {
      return false;
    }

    try {
      await execute();
      span.status = SpanStatus.aborted();
      return true;
    } catch (exception) {
      span.throwable = exception;
      span.status = SpanStatus.internalError();
      rethrow;
    } finally {
      await span.finish();
      _transactionStack.removeLast();
    }
  }
}
