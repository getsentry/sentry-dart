import 'package:drift/backends.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_drift/src/sentry_span_helper.dart';

class SentryTransactionExecutor extends TransactionExecutor {
  final TransactionExecutor _executor;

  final Hub _hub;

  final _spanHelper = SentrySpanHelper(
    // ignore: invalid_use_of_internal_member
    SentryTraceOrigins.autoDbDriftTransactionExecutor,
  );

  final String? _dbName;

  SentryTransactionExecutor(this._executor, Hub hub, {@internal String? dbName})
      : _hub = hub,
        _dbName = dbName {
    _spanHelper.setHub(_hub);
    beginTransaction();
  }

  @override
  TransactionExecutor beginTransaction() {
    return _spanHelper.beginTransaction('transaction', () {
      return _executor.beginTransaction();
    }, dbName: _dbName);
  }

  @override
  Future<void> rollback() {
    return _spanHelper.abortTransaction(() async {
      return await _executor.rollback();
    });
  }

  @override
  Future<void> send() {
    return _spanHelper.finishTransaction(() async {
      return await _executor.send();
    });
  }

  @override
  SqlDialect get dialect => _executor.dialect;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) {
    return _executor.ensureOpen(user);
  }

  @override
  Future<void> runBatched(BatchedStatements statements) {
    return _executor.runBatched(statements);
  }

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) {
    return _executor.runCustom(statement, args);
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) {
    return _executor.runDelete(statement, args);
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) {
    return _executor.runInsert(statement, args);
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
      String statement, List<Object?> args) {
    return _executor.runSelect(statement, args);
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) {
    return _executor.runUpdate(statement, args);
  }

  @override
  bool get supportsNestedTransactions => _executor.supportsNestedTransactions;
}
