import 'dart:async';

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'package:sqflite/sqflite.dart';

import 'sentry_database_executor.dart';
import 'sentry_sqflite_transaction.dart';
import 'version.dart';
import 'utils/sentry_sqflite_span_helper.dart';
import 'package:path/path.dart' as p;

/// A [Database] wrapper that adds Sentry support.
///
/// ```dart
/// import 'package:sqflite/sqflite.dart';
/// import 'package:sentry_sqflite/sentry_sqflite.dart';
///
/// final database = await openDatabase('path/to/db');
/// final sentryDatabase = SentryDatabase(database);
/// ```
@experimental
class SentryDatabase extends SentryDatabaseExecutor implements Database {
  final Database _database;
  final Hub _hub;
  final SentrySqfliteSpanHelper _helper;

  @internal
  // ignore: public_member_api_docs
  static const dbOp = 'db';
  @internal
  // ignore: public_member_api_docs
  static const dbSqlExecuteOp = 'db.sql.execute';
  @internal
  // ignore: public_member_api_docs
  static const dbSqlQueryOp = 'db.sql.query';

  static const _dbSqlTransactionOp = 'db.sql.transaction';

  static const _dbSqlReadTransactionOp = 'db.sql.read_transaction';

  @internal
  // ignore: public_member_api_docs
  static const dbSystemKey = 'db.system';
  @internal
  // ignore: public_member_api_docs
  static const dbSystem = 'sqlite';
  @internal
  // ignore: public_member_api_docs
  static const dbNameKey = 'db.name';
  @internal
  // ignore: public_member_api_docs
  String dbName;

  /// ```dart
  /// import 'package:sqflite/sqflite.dart';
  /// import 'package:sentry_sqflite/sentry_sqflite.dart';
  ///
  /// final database = await openDatabase('path/to/db');
  /// final sentryDatabase = SentryDatabase(database);
  /// ```
  SentryDatabase(
    this._database, {
    @internal Hub? hub,
  })  : _hub = hub ?? HubAdapter(),
        dbName = p.basenameWithoutExtension(_database.path),
        _helper = SentrySqfliteSpanHelper(
          spanWrapper:
              // ignore: invalid_use_of_internal_member
              (hub ?? HubAdapter()).options.spanWrapper,
          hub: hub ?? HubAdapter(),
          dbName: p.basenameWithoutExtension(_database.path),
        ),
        super(
          _database,
          hub: hub,
          dbName: p.basenameWithoutExtension(_database.path),
        ) {
    // ignore: invalid_use_of_internal_member
    final options = _hub.options;
    options.sdk.addIntegration('SentrySqfliteTracing');
    options.sdk.addPackage(packageName, sdkVersion);
  }

  // TODO: check if perf is enabled

  @override
  Future<void> close() {
    return _helper.wrapAsync<void>(
      operation: dbOp,
      description: 'Close DB: ${_database.path}',
      execute: () => _database.close(),
      // ignore: invalid_use_of_internal_member
      origin: SentryTraceOrigins.autoDbSqfliteDatabase,
      parentSpan: _hub.getSpan(),
    );
  }

  @override
  Future<T> devInvokeMethod<T>(String method, [Object? arguments]) {
    // ignore: deprecated_member_use
    return _database.devInvokeMethod(method, arguments);
  }

  @override
  Future<T> devInvokeSqlMethod<T>(
    String method,
    String sql, [
    List<Object?>? arguments,
  ]) {
    // ignore: deprecated_member_use
    return _database.devInvokeSqlMethod(method, sql);
  }

  @override
  bool get isOpen => _database.isOpen;

  @override
  String get path => _database.path;

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) {
    return _helper.wrapTransaction<T>(
      operation: _dbSqlTransactionOp,
      description: 'Transaction DB: ${_database.path}',
      // ignore: invalid_use_of_internal_member
      origin: SentryTraceOrigins.autoDbSqfliteDatabase,
      parentSpan: _hub.getSpan(),
      execute: (transactionSpan) async {
        Future<T> newAction(Transaction txn) async {
          final executor = SentryDatabaseExecutor(
            txn,
            parentSpan: transactionSpan,
            hub: _hub,
            dbName: dbName,
          );
          final sentrySqfliteTransaction =
              SentrySqfliteTransaction(executor, hub: _hub, dbName: dbName);

          return await action(sentrySqfliteTransaction);
        }

        return await _database.transaction(newAction, exclusive: exclusive);
      },
    );
  }

  @override
  // ignore: override_on_non_overriding_member, public_member_api_docs
  Future<T> readTransaction<T>(Future<T> Function(Transaction txn) action) {
    return _helper.wrapTransaction<T>(
      operation: _dbSqlReadTransactionOp,
      description: 'Transaction DB: ${_database.path}',
      // ignore: invalid_use_of_internal_member
      origin: SentryTraceOrigins.autoDbSqfliteDatabase,
      parentSpan: _hub.getSpan(),
      execute: (transactionSpan) async {
        Future<T> newAction(Transaction txn) async {
          final executor = SentryDatabaseExecutor(
            txn,
            parentSpan: transactionSpan,
            hub: _hub,
            dbName: dbName,
          );
          final sentrySqfliteTransaction =
              SentrySqfliteTransaction(executor, hub: _hub, dbName: dbName);

          return await action(sentrySqfliteTransaction);
        }

        final futureOrResult = _resolvedReadTransaction(newAction);
        T result;

        if (futureOrResult is Future<T>) {
          result = await futureOrResult;
        } else {
          result = futureOrResult;
        }

        return result;
      },
    );
  }

  FutureOr<T> _resolvedReadTransaction<T>(
    Future<T> Function(Transaction txn) action,
  ) async {
    try {
      // ignore: return_of_invalid_type
      final result = await (_database as dynamic).readTransaction(action);
      // Await and cast, as directly returning the future resulted in a runtime error.
      return result as T;
    } on NoSuchMethodError catch (_) {
      // The `readTransaction` does not exists on sqflite version < 2.5.0+2.
      // Fallback to transaction instead.
      return _database.transaction(action);
    }
  }
}
