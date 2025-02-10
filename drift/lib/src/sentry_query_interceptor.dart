import 'dart:async';

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import 'constants.dart' as constants;
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

  SentryQueryInterceptor({required String databaseName, @internal Hub? hub})
      : _dbName = databaseName {
    _spanHelper = SentrySpanHelper(
      // ignore: invalid_use_of_internal_member
      SentryTraceOrigins.autoDbDriftQueryInterceptor,
      hub: hub,
    );
    // ignore: invalid_use_of_internal_member
    final options = hub?.options;
    options?.sdk.addIntegration(constants.integrationName);
    options?.sdk.addPackage(packageName, sdkVersion);
  }

  Future<T> _run<T>(
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
    if (!_isDbOpen) {
      _isDbOpen = true;
      return _run(
        constants.dbOpenDesc(dbName: _dbName),
        () => super.ensureOpen(executor, user),
        operation: constants.dbOpenOp,
      );
    }
    return super.ensureOpen(executor, user);
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
    return _run(
      constants.dbCloseDesc(dbName: _dbName),
      () => super.close(inner),
      operation: constants.dbCloseOp,
    );
  }

  @override
  Future<void> runBatched(
      QueryExecutor executor, BatchedStatements statements) {
    return _run(
      constants.dbBatchDesc,
      () => super.runBatched(executor, statements),
      operation: constants.dbSqlBatchOp,
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
    return _run(
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
    return _run(statement, () => executor.runUpdate(statement, args));
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    return _run(statement, () => executor.runDelete(statement, args));
  }

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    return _run(statement, () => executor.runCustom(statement, args));
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    return _run(statement, () => executor.runSelect(statement, args));
  }
}
