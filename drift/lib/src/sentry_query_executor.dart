import 'dart:async';

import 'package:drift/backends.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'sentry_span_helper.dart';
import 'sentry_transaction_executor.dart';

/// Signature of a function that opens a database connection when instructed to.
typedef DatabaseOpener = FutureOr<QueryExecutor> Function();

/// The Sentry Query Executor.
///
/// If the constructor parameter queryExecutor is not null, it will be used
/// instead of the default [LazyDatabase].
@experimental
class SentryQueryExecutor extends QueryExecutor {
  Hub _hub;

  final _spanHelper = SentrySpanHelper(
    // ignore: invalid_use_of_internal_member
    SentryTraceOrigins.autoDbDriftQueryExecutor,
  );

  final QueryExecutor _queryExecutor;

  final String? _dbName;

  @internal
  // ignore: public_member_api_docs
  static const dbNameKey = 'db.name';

  @internal
  // ignore: public_member_api_docs
  static const dbOp = 'db';

  @internal
  // ignore: public_member_api_docs
  static const dbSystemKey = 'db.system';

  @internal
  // ignore: public_member_api_docs
  static const dbSystem = 'sqlite';

  /// Declares a [SentryQueryExecutor] that will run [opener] when the database is
  /// first requested to be opened. You must specify the same [dialect] as the
  /// underlying database has
  SentryQueryExecutor(DatabaseOpener opener,
      {@internal Hub? hub,
      @internal QueryExecutor? queryExecutor,
      required String databaseName})
      : _hub = hub ?? HubAdapter(),
        _dbName = databaseName,
        _queryExecutor = queryExecutor ?? LazyDatabase(opener) {
    _spanHelper.setHub(_hub);
  }

  @internal
  void setHub(Hub hub) {
    _hub = hub;
    _spanHelper.setHub(hub);
  }

  @override
  TransactionExecutor beginTransaction() {
    final transactionExecutor = _queryExecutor.beginTransaction();
    return SentryTransactionExecutor(transactionExecutor, _hub,
        dbName: _dbName);
  }

  @override
  Future<void> runBatched(BatchedStatements statements) {
    return _spanHelper.asyncWrapInSpan('batch', () async {
      return await _queryExecutor.runBatched(statements);
    }, dbName: _dbName);
  }

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) {
    return _spanHelper.asyncWrapInSpan('open', () async {
      return await _queryExecutor.ensureOpen(user);
    }, dbName: _dbName);
  }

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) {
    return _spanHelper.asyncWrapInSpan('custom', () async {
      return await _queryExecutor.runCustom(statement, args);
    }, dbName: _dbName);
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) {
    return _spanHelper.asyncWrapInSpan('delete', () async {
      return await _queryExecutor.runDelete(statement, args);
    }, dbName: _dbName);
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) {
    return _spanHelper.asyncWrapInSpan('insert', () async {
      return await _queryExecutor.runInsert(statement, args);
    }, dbName: _dbName);
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
      String statement, List<Object?> args) {
    return _spanHelper.asyncWrapInSpan('select', () async {
      return await _queryExecutor.runSelect(statement, args);
    }, dbName: _dbName);
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) {
    return _spanHelper.asyncWrapInSpan('update', () async {
      return await _queryExecutor.runUpdate(statement, args);
    }, dbName: _dbName);
  }

  @override
  Future<void> close() {
    return _spanHelper.asyncWrapInSpan('close', () async {
      return await _queryExecutor.close();
    }, dbName: _dbName);
  }

  @override
  SqlDialect get dialect => _queryExecutor.dialect;
}
