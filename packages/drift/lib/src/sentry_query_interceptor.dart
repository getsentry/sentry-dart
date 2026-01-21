// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:collection';

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import 'constants.dart' as drift_constants;
import 'version.dart';

/// A Sentry query interceptor that wraps database operations in performance monitoring spans.
///
/// This interceptor tracks all database operations executed through a Drift database connection,
/// including transactions, batches, and individual CRUD operations. Each operation is captured
/// as a Sentry span with relevant context.
class SentryQueryInterceptor extends QueryInterceptor {
  final String _dbName;
  final Hub _hub;
  bool _isDbOpen = false;

  /// Stack of active transaction spans for nested transaction support.
  final ListQueue<ISentrySpan?> _transactionStack = ListQueue();

  /// Returns the transaction stack for testing purposes.
  @visibleForTesting
  ListQueue<ISentrySpan?> get transactionStack => _transactionStack;

  /// Returns the current transaction span from the stack, or null if empty.
  ISentrySpan? get _currentTransaction => _transactionStack.lastOrNull;

  SentryQueryInterceptor({required String databaseName, @internal Hub? hub})
      : _dbName = databaseName,
        _hub = hub ?? HubAdapter() {
    final options = _hub.options;
    options.sdk.addIntegration(drift_constants.integrationName);
    options.sdk.addPackage(packageName, sdkVersion);
  }

  SpanWrapper get _spanWrapper => _hub.options.spanWrapper;

  /// Wraps database operations in Sentry spans.
  ///
  /// Uses the current transaction span as parent if available, otherwise
  /// falls back to the hub's active span.
  Future<T> _instrumentOperation<T>(
    String description,
    FutureOr<T> Function() execute, {
    String? operation,
  }) async =>
      _spanWrapper.wrapAsync<T>(
        operation: operation ?? SentrySpanOperations.dbSqlQuery,
        description: description,
        execute: () async => execute(),
        origin: SentryTraceOrigins.autoDbDriftQueryInterceptor,
        attributes: {
          SentrySpanData.dbSystemKey: SentrySpanData.dbSystemSqlite,
          SentrySpanData.dbNameKey: _dbName,
        },
        parentSpan: _currentTransaction,
      );

  @override
  Future<bool> ensureOpen(QueryExecutor executor, QueryExecutorUser user) {
    if (_isDbOpen) {
      return super.ensureOpen(executor, user);
    }
    return _instrumentOperation(
      SentrySpanDescriptions.dbOpen(dbName: _dbName),
      () async {
        final result = await super.ensureOpen(executor, user);
        _isDbOpen = true;
        return result;
      },
      operation: SentrySpanOperations.dbOpen,
    );
  }

  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) {
    final parentSpan = _currentTransaction ?? _hub.getSpan();
    if (parentSpan == null) {
      return super.beginTransaction(parent);
    }

    final span = parentSpan.startChild(
      SentrySpanOperations.dbSqlTransaction,
      description: SentrySpanDescriptions.dbTransaction,
    );
    span.origin = SentryTraceOrigins.autoDbDriftQueryInterceptor;
    span.setData(SentrySpanData.dbSystemKey, SentrySpanData.dbSystemSqlite);
    span.setData(SentrySpanData.dbNameKey, _dbName);

    try {
      final result = super.beginTransaction(parent);
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
  Future<void> close(QueryExecutor inner) {
    return _instrumentOperation(
      SentrySpanDescriptions.dbClose(dbName: _dbName),
      () => super.close(inner),
      operation: SentrySpanOperations.dbClose,
    );
  }

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) {
    final description =
        SentrySpanDescriptions.dbBatch(statements: statements.statements);
    return _instrumentOperation(
      description,
      () => super.runBatched(executor, statements),
      operation: SentrySpanOperations.dbSqlBatch,
    );
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    final span = _transactionStack.lastOrNull;
    if (span == null) {
      return super.commitTransaction(inner);
    }

    try {
      await super.commitTransaction(inner);
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
  Future<void> rollbackTransaction(TransactionExecutor inner) async {
    final span = _transactionStack.lastOrNull;
    if (span == null) {
      return super.rollbackTransaction(inner);
    }

    try {
      await super.rollbackTransaction(inner);
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

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    return _instrumentOperation(
      statement,
      () => executor.runInsert(statement, args),
    );
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    return _instrumentOperation(
      statement,
      () => executor.runUpdate(statement, args),
    );
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    return _instrumentOperation(
      statement,
      () => executor.runDelete(statement, args),
    );
  }

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    return _instrumentOperation(
      statement,
      () => executor.runCustom(statement, args),
    );
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    return _instrumentOperation(
      statement,
      () => executor.runSelect(statement, args),
    );
  }
}
