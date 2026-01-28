// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import 'utils/constants.dart' as drift_constants;
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

  /// Returns the number of active transaction spans in the stack.
  ///
  /// This is used for testing to verify that transactions are properly
  /// cleaned up after commit/rollback operations.
  @visibleForTesting
  int get transactionStackSize => _transactionWrapper.transactionStackSize;

  TransactionWrapper get _transactionWrapper => _hub.options.transactionWrapper;
  SpanWrapper get _spanWrapper => _hub.options.spanWrapper;

  SentryQueryInterceptor({
    required String databaseName,
    @internal Hub? hub,
  })  : _dbName = databaseName,
        _hub = hub ?? HubAdapter() {
    final options = _hub.options;
    options.sdk.addIntegration(drift_constants.integrationName);
    options.sdk.addPackage(packageName, sdkVersion);
  }

  /// Instruments non-transactional database operations with Sentry spans.
  Future<T> _instrumentOperation<T>(
    String description,
    FutureOr<T> Function() execute, {
    String? operation,
  }) =>
      _spanWrapper.wrapAsync<T>(
        operation: operation ?? SentrySpanOperations.dbSqlQuery,
        description: description,
        execute: () async => execute(),
        loggerName: drift_constants.loggerName,
        origin: SentryTraceOrigins.autoDbDriftQueryInterceptor,
        attributes: {
          SentrySpanData.dbSystemKey: SentrySpanData.dbSystemSqlite,
          SentrySpanData.dbNameKey: _dbName,
        },
        parentSpan: _transactionWrapper.currentSpan ?? _hub.getSpan(),
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
    return _transactionWrapper.beginTransaction<TransactionExecutor>(
      operation: SentrySpanOperations.dbSqlTransaction,
      description: SentrySpanDescriptions.dbTransaction,
      execute: () => super.beginTransaction(parent),
      loggerName: drift_constants.loggerName,
      origin: SentryTraceOrigins.autoDbDriftQueryInterceptor,
      attributes: {
        SentrySpanData.dbSystemKey: SentrySpanData.dbSystemSqlite,
        SentrySpanData.dbNameKey: _dbName,
      },
    );
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
    await _transactionWrapper.commitTransaction(
      execute: () => super.commitTransaction(inner),
      loggerName: drift_constants.loggerName,
    );
  }

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) async {
    await _transactionWrapper.rollbackTransaction(
      execute: () => super.rollbackTransaction(inner),
      loggerName: drift_constants.loggerName,
    );
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
