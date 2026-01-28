// ignore_for_file: invalid_use_of_internal_member

import 'dart:collection';
import 'dart:async';

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import 'internal_logger.dart';

@internal
class SentrySpanHelper {
  final Hub _hub;
  final String _origin;
  late final InstrumentationSpanFactory _factory;

  /// Represents a stack of Drift transaction spans.
  /// These are used to allow nested spans if the user nests Drift transactions.
  /// If the transaction stack is empty, the spans are attached to the
  /// active span in the Hub's scope.
  final ListQueue<InstrumentationSpan> _transactionStack = ListQueue();

  @visibleForTesting
  ListQueue<InstrumentationSpan> get transactionStack => _transactionStack;

  SentrySpanHelper(this._origin, {Hub? hub}) : _hub = hub ?? HubAdapter() {
    _factory = _hub.options.spanFactory;
  }

  /// Gets the parent span for operations.
  /// Returns the last transaction on the stack, or falls back to the current
  /// span from the hub's scope if the stack is empty.
  InstrumentationSpan? _getParent() {
    return _transactionStack.lastOrNull ?? _factory.getSpan(_hub);
  }

  Future<T> asyncWrapInSpan<T>(
    String description,
    Future<T> Function() execute, {
    String? dbName,
    String? operation,
  }) async {
    final parentSpan = _getParent();
    if (parentSpan == null) {
      internalLogger.warning(
        'No active span found. Skipping tracing for Drift operation: $description',
      );
      return execute();
    }

    final span = _factory.createSpan(
      parentSpan,
      operation ?? SentrySpanOperations.dbSqlQuery,
      description: description,
    );

    if (span == null) {
      return execute();
    }

    span.origin = _origin;

    span.setData(
      SentrySpanData.dbSystemKey,
      SentrySpanData.dbSystemSqlite,
    );

    if (dbName != null) {
      span.setData(SentrySpanData.dbNameKey, dbName);
    }

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

  T beginTransaction<T>(
    T Function() execute, {
    String? dbName,
  }) {
    final parentSpan = _getParent();
    if (parentSpan == null) {
      internalLogger.warning(
        'No active span found. Skipping tracing for Drift beginTransaction.',
      );
      return execute();
    }

    final newParent = _factory.createSpan(
      parentSpan,
      SentrySpanOperations.dbSqlTransaction,
      description: SentrySpanDescriptions.dbTransaction,
    );

    if (newParent == null) {
      return execute();
    }

    newParent.origin = _origin;

    newParent.setData(
      SentrySpanData.dbSystemKey,
      SentrySpanData.dbSystemSqlite,
    );

    if (dbName != null) {
      newParent.setData(SentrySpanData.dbNameKey, dbName);
    }

    try {
      final result = execute();
      newParent.status = SpanStatus.unknown();

      _transactionStack.add(newParent);

      return result;
    } catch (exception) {
      newParent.throwable = exception;
      newParent.status = SpanStatus.internalError();
      unawaited(newParent.finish());

      rethrow;
    }
  }

  Future<T> finishTransaction<T>(Future<T> Function() execute) async {
    if (_transactionStack.isEmpty) {
      internalLogger.warning(
        'Transaction stack is empty. Skipping span finish for Drift commitTransaction.',
      );
      return execute();
    }

    final parentSpan = _transactionStack.last;

    try {
      final result = await execute();
      parentSpan.status = SpanStatus.ok();

      return result;
    } catch (exception) {
      parentSpan.throwable = exception;
      parentSpan.status = SpanStatus.internalError();

      rethrow;
    } finally {
      await parentSpan.finish();
      _transactionStack.removeLast();
    }
  }

  Future<T> abortTransaction<T>(Future<T> Function() execute) async {
    if (_transactionStack.isEmpty) {
      internalLogger.warning(
        'Transaction stack is empty. Skipping span finish for Drift rollbackTransaction.',
      );
      return execute();
    }

    final parentSpan = _transactionStack.last;

    try {
      final result = await execute();
      parentSpan.status = SpanStatus.aborted();

      return result;
    } catch (exception) {
      parentSpan.throwable = exception;
      parentSpan.status = SpanStatus.internalError();

      rethrow;
    } finally {
      await parentSpan.finish();
      _transactionStack.removeLast();
    }
  }
}
