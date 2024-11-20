import 'package:drift/backends.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import 'sentry_span_helper.dart';

/// @nodoc
@internal
class SentryTransactionExecutor extends TransactionExecutor {
  final TransactionExecutor _executor;

  final Hub _hub;

  final _spanHelper = SentrySpanHelper(
    // ignore: invalid_use_of_internal_member
    SentryTraceOrigins.autoDbDriftTransactionExecutor,
  );

  final String? _dbName;

  bool _isOpen = false;

  final _withinTransactionDescription = 'Within transaction: ';

  /// @nodoc
  SentryTransactionExecutor(this._executor, Hub hub, {@internal String? dbName})
      : _hub = hub,
        _dbName = dbName {
    _spanHelper.setHub(_hub);
  }

  @override
  TransactionExecutor beginTransaction() {
    return _spanHelper.beginTransaction(
      'transaction',
      () {
        return _executor.beginTransaction();
      },
      dbName: _dbName,
    );
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
    if (_isOpen) {
      return Future.value(true);
    }
    return _spanHelper.asyncWrapInSpan(
      'Open transaction',
      () async {
        final res = await _executor.ensureOpen(user);
        _isOpen = true;
        return res;
      },
      dbName: _dbName,
    );
  }

  @override
  Future<void> runBatched(BatchedStatements statements) {
    return _spanHelper.asyncWrapInSpan(
      'batch',
      () async {
        return await _executor.runBatched(statements);
      },
      dbName: _dbName,
    );
  }

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) {
    return _spanHelper.asyncWrapInSpan(
      _spanDescriptionForOperations(statement),
      () async {
        return _executor.runCustom(statement, args);
      },
      dbName: _dbName,
      useTransactionSpan: true,
    );
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) {
    return _spanHelper.asyncWrapInSpan(
      _spanDescriptionForOperations(statement),
      () async {
        return _executor.runDelete(statement, args);
      },
      dbName: _dbName,
      useTransactionSpan: true,
    );
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) {
    return _spanHelper.asyncWrapInSpan(
      _spanDescriptionForOperations(statement),
      () async {
        return _executor.runInsert(statement, args);
      },
      dbName: _dbName,
      useTransactionSpan: true,
    );
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) {
    return _spanHelper.asyncWrapInSpan(
      _spanDescriptionForOperations(statement),
      () async {
        return _executor.runSelect(statement, args);
      },
      dbName: _dbName,
      useTransactionSpan: true,
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
  Future<int> runUpdate(String statement, List<Object?> args) {
    return _spanHelper.asyncWrapInSpan(
      _spanDescriptionForOperations(statement),
      () async {
        return _executor.runUpdate(statement, args);
      },
      dbName: _dbName,
      useTransactionSpan: true,
    );
  }

  @override
  bool get supportsNestedTransactions => _executor.supportsNestedTransactions;

  String _spanDescriptionForOperations(String operation) {
    return '$_withinTransactionDescription$operation';
  }
}
