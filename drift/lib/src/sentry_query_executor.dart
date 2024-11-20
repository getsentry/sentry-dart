import 'dart:async';

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import 'sentry_span_helper.dart';
import 'sentry_transaction_executor.dart';
import 'version.dart';

/// Signature of a function that opens a database connection when instructed to.
typedef DatabaseOpener = FutureOr<QueryExecutor> Function();

/// The Sentry Query Executor.
///
/// If the constructor parameter queryExecutor is null, [LazyDatabase] will be
/// used as a default.
@experimental
class SentryQueryExecutor extends QueryExecutor {
  Hub _hub;

  final _spanHelper = SentrySpanHelper(
    // ignore: invalid_use_of_internal_member
    SentryTraceOrigins.autoDbDriftQueryExecutor,
  );

  final QueryExecutor _executor;

  final String _dbName;

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

  bool _isOpen = false;

  /// Declares a [SentryQueryExecutor] that will run [opener] when the database is
  /// first requested to be opened. You must specify the same [dialect] as the
  /// underlying database has
  SentryQueryExecutor(
    DatabaseOpener opener, {
    @internal Hub? hub,
    @internal QueryExecutor? queryExecutor,
    required String databaseName,
  })  : _hub = hub ?? HubAdapter(),
        _dbName = databaseName,
        _executor = queryExecutor ?? LazyDatabase(opener) {
    // ignore: invalid_use_of_internal_member
    final options = _hub.options;
    options.sdk.addIntegration('SentryDriftTracing');
    options.sdk.addPackage(packageName, sdkVersion);
    _spanHelper.setHub(_hub);
  }

  /// @nodoc
  @internal
  void setHub(Hub hub) {
    _hub = hub;
    _spanHelper.setHub(hub);
  }

  @override
  TransactionExecutor beginTransaction() {
    final transactionExecutor = _executor.beginTransaction();
    final sentryTransactionExecutor = SentryTransactionExecutor(
      transactionExecutor,
      _hub,
      dbName: _dbName,
    );
    sentryTransactionExecutor.beginTransaction();
    return sentryTransactionExecutor;
  }

  @override
  Future<void> runBatched(BatchedStatements statements) {
    return _spanHelper.asyncWrapInSpan(
      statements.toString(),
      () async {
        return await _executor.runBatched(statements);
      },
      dbName: _dbName,
    );
  }

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) {
    if (_isOpen) {
      return Future.value(true);
    }
    return _spanHelper.asyncWrapInSpan(
      'Open DB: $_dbName',
      () async {
        final res = await _executor.ensureOpen(user);
        _isOpen = true;
        return res;
      },
      dbName: _dbName,
    );
  }

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) {
    return _spanHelper.asyncWrapInSpan(
      statement,
      () async {
        return await _executor.runCustom(statement, args);
      },
      dbName: _dbName,
    );
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) {
    return _spanHelper.asyncWrapInSpan(
      statement,
      () async {
        return await _executor.runDelete(statement, args);
      },
      dbName: _dbName,
    );
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) {
    return _spanHelper.asyncWrapInSpan(
      statement,
      () async {
        return await _executor.runInsert(statement, args);
      },
      dbName: _dbName,
    );
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) {
    return _spanHelper.asyncWrapInSpan(
      statement,
      () async {
        return await _executor.runSelect(statement, args);
      },
      dbName: _dbName,
    );
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) {
    return _spanHelper.asyncWrapInSpan(
      statement,
      () async {
        return await _executor.runUpdate(statement, args);
      },
      dbName: _dbName,
    );
  }

  @override
  // ignore: override_on_non_overriding_member, public_member_api_docs
  QueryExecutor beginExclusive() {
    final dynamic uncheckedExecutor = _executor;
    try {
      return uncheckedExecutor.beginExclusive() as QueryExecutor;
    } on NoSuchMethodError catch (_) {
      throw Exception('This method is not supported in Drift versions <2.19.0');
    }
  }

  @override
  Future<void> close() {
    return _spanHelper.asyncWrapInSpan(
      'Close DB: $_dbName',
      () async {
        return await _executor.close();
      },
      dbName: _dbName,
    );
  }

  @override
  SqlDialect get dialect => _executor.dialect;
}
