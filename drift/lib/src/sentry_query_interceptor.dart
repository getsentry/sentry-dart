import 'dart:async';

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import 'sentry_span_helper.dart';

/// Doc
class SentryQueryInterceptor extends QueryInterceptor {
  final String _dbName;
  final Hub _hub;

  final _spanHelper = NewSentrySpanHelper(
    // ignore: invalid_use_of_internal_member
    SentryTraceOrigins.autoDbDriftQueryExecutor,
  );

  /// @nodoc
  SentryQueryInterceptor({required String databaseName, @internal Hub? hub})
      : _dbName = databaseName,
        _hub = hub ?? HubAdapter();

  Future<T> _run<T>(
    String description,
    FutureOr<T> Function() operation,
  ) async {
    return await _spanHelper.asyncWrapInSpan<T>(
      description,
      () async => operation(),
      dbName: _dbName,
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
  Future<void> commitTransaction(TransactionExecutor inner) {
    return _spanHelper.finishTransaction(() => super.commitTransaction(inner));
  }

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) {
    return _spanHelper.abortTransaction(() => super.rollbackTransaction(inner));
  }

  @override
  Future<void> runBatched(
      QueryExecutor executor, BatchedStatements statements) {
    return _run(
        'batch with $statements', () => executor.runBatched(statements));
  }

  @override
  Future<int> runInsert(
      QueryExecutor executor, String statement, List<Object?> args) {
    print('run insert');
    return _run(
      '$statement with $args',
      () => executor.runInsert(statement, args),
    );
  }

  @override
  Future<int> runUpdate(
      QueryExecutor executor, String statement, List<Object?> args) {
    return _run(
        '$statement with $args', () => executor.runUpdate(statement, args));
  }

  @override
  Future<int> runDelete(
      QueryExecutor executor, String statement, List<Object?> args) {
    return _run(
        '$statement with $args', () => executor.runDelete(statement, args));
  }

  @override
  Future<void> runCustom(
      QueryExecutor executor, String statement, List<Object?> args) {
    return _run(
        '$statement with $args', () => executor.runCustom(statement, args));
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
      QueryExecutor executor, String statement, List<Object?> args) {
    return _run(
        '$statement with $args', () => executor.runSelect(statement, args));
  }
}
