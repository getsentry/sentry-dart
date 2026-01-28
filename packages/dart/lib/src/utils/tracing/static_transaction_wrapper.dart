// ignore_for_file: invalid_use_of_internal_member

import 'dart:collection';

import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../internal_logger.dart';

@internal
class StaticTransactionWrapper implements TransactionWrapper {
  final Hub _hub;
  final ListQueue<ISentrySpan?> _transactionStack = ListQueue();

  StaticTransactionWrapper({Hub? hub}) : _hub = hub ?? HubAdapter();

  @override
  int get transactionStackSize => _transactionStack.length;

  @override
  ISentrySpan? get currentSpan => _transactionStack.lastOrNull;

  @override
  T beginTransaction<T>({
    required String operation,
    required String description,
    required T Function() execute,
    required String loggerName,
    String? origin,
    Map<String, Object>? attributes,
  }) {
    final parent = currentSpan ?? _hub.getSpan();
    if (parent == null) {
      internalLogger.warning(
        'No active transaction found for $loggerName. The operation `beginTransaction` will not be traced',
      );
      return execute();
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
      return result;
    } catch (exception) {
      span.throwable = exception;
      span.status = SpanStatus.internalError();
      span.finish();
      rethrow;
    }
  }

  @override
  Future<void> commitTransaction({
    required Future<void> Function() execute,
    required String loggerName,
  }) async {
    final span = _transactionStack.lastOrNull;
    if (span == null) {
      internalLogger.warning(
        'No active transaction found for $loggerName. The operation `commitTransaction` will not be traced',
      );
      return execute();
    }

    try {
      await execute();
      span.status = SpanStatus.ok();
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
  Future<void> rollbackTransaction({
    required Future<void> Function() execute,
    required String loggerName,
  }) async {
    final span = _transactionStack.lastOrNull;
    if (span == null) {
      internalLogger.warning(
        'No active transaction found for $loggerName. The operation `rollbackTransaction` will not be traced',
      );
      return execute();
    }

    try {
      await execute();
      span.status = SpanStatus.aborted();
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
