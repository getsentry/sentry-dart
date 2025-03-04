// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import 'constants.dart' as drift_constants;
import 'sentry_span_helper.dart';
import 'version.dart';

/// A Sentry query interceptor that wraps database operations in performance monitoring spans.
///
/// This interceptor tracks all database operations executed through a Drift database connection,
/// including transactions, batches, and individual CRUD operations. Each operation is captured
/// as a Sentry span with relevant context.
class SentryQueryInterceptor extends QueryInterceptor {
  final String _dbName;
  late final SentrySpanHelper _spanHelper;
  bool _isDbOpen = false;

  @visibleForTesting
  SentrySpanHelper get spanHelper => _spanHelper;

  SentryQueryInterceptor({required String databaseName, @internal Hub? hub})
      : _dbName = databaseName {
    hub = hub ?? HubAdapter();
    _spanHelper = SentrySpanHelper(
      SentryTraceOrigins.autoDbDriftQueryInterceptor,
      hub: hub,
    );
    final options = hub.options;
    options.sdk.addIntegration(drift_constants.integrationName);
    options.sdk.addPackage(packageName, sdkVersion);
  }

  /// Wraps database operations in Sentry spans.
  ///
  /// This handles most CRUD operations but excludes transaction lifecycle methods
  /// (begin/commit/rollback), which require maintaining an ongoing transaction span
  /// across multiple operations. Those are handled separately via [SentrySpanHelper].
  Future<T> _instrumentOperation<T>(
    String description,
    FutureOr<T> Function() execute, {
    String? operation,
  }) async =>
      _spanHelper.asyncWrapInSpan<T>(
        description,
        () async => execute(),
        dbName: _dbName,
        operation: operation,
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
    return _spanHelper.beginTransaction(
      () => super.beginTransaction(parent),
      dbName: _dbName,
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
  Future<void> commitTransaction(TransactionExecutor inner) {
    return _spanHelper.finishTransaction(() => super.commitTransaction(inner));
  }

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) {
    return _spanHelper.abortTransaction(() => super.rollbackTransaction(inner));
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
