import 'dart:async';

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'package:sqflite/sqflite.dart';

import 'sentry_database_executor.dart';
import 'sentry_sqflite_transaction.dart';
import 'version.dart';
import 'utils/sentry_database_span_attributes.dart';
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
    return Future<void>(() async {
      final currentSpan = _hub.getSpan();
      final description = 'Close DB: ${_database.path}';
      final span = currentSpan?.startChild(
        dbOp,
        description: description,
      );
      // ignore: invalid_use_of_internal_member
      span?.origin = SentryTraceOrigins.autoDbSqfliteDatabase;

      var breadcrumb = Breadcrumb(
        message: description,
        category: dbOp,
        data: {},
        type: 'query',
      );

      try {
        await _database.close();

        span?.status = SpanStatus.ok();
        breadcrumb.data?['status'] = 'ok';
      } catch (exception) {
        span?.throwable = exception;
        span?.status = SpanStatus.internalError();
        breadcrumb.data?['status'] = 'internal_error';
        breadcrumb = breadcrumb.copyWith(
          level: SentryLevel.warning,
        );

        rethrow;
      } finally {
        await span?.finish();
        // ignore: invalid_use_of_internal_member
        await _hub.scope.addBreadcrumb(breadcrumb);
      }
    });
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
    return Future<T>(() async {
      final currentSpan = _hub.getSpan();
      final description = 'Transaction DB: ${_database.path}';
      final span = currentSpan?.startChild(
        _dbSqlTransactionOp,
        description: description,
      );
      // ignore: invalid_use_of_internal_member
      span?.origin = SentryTraceOrigins.autoDbSqfliteDatabase;
      setDatabaseAttributeData(span, dbName);

      var breadcrumb = Breadcrumb(
        message: description,
        category: _dbSqlTransactionOp,
        data: {},
        type: 'query',
      );
      setDatabaseAttributeOnBreadcrumb(breadcrumb, dbName);

      Future<T> newAction(Transaction txn) async {
        final executor = SentryDatabaseExecutor(
          txn,
          parentSpan: span,
          hub: _hub,
          dbName: dbName,
        );
        final sentrySqfliteTransaction =
            SentrySqfliteTransaction(executor, hub: _hub, dbName: dbName);

        return await action(sentrySqfliteTransaction);
      }

      try {
        final result =
            await _database.transaction(newAction, exclusive: exclusive);

        span?.status = SpanStatus.ok();
        breadcrumb.data?['status'] = 'ok';

        return result;
      } catch (exception) {
        span?.throwable = exception;
        span?.status = SpanStatus.internalError();
        breadcrumb.data?['status'] = 'internal_error';
        breadcrumb = breadcrumb.copyWith(
          level: SentryLevel.warning,
        );

        rethrow;
      } finally {
        await span?.finish();

        // ignore: invalid_use_of_internal_member
        await _hub.scope.addBreadcrumb(breadcrumb);
      }
    });
  }

  @override
  // ignore: override_on_non_overriding_member, public_member_api_docs
  Future<T> readTransaction<T>(Future<T> Function(Transaction txn) action) {
    return Future<T>(() async {
      final currentSpan = _hub.getSpan();
      final description = 'Transaction DB: ${_database.path}';
      final span = currentSpan?.startChild(
        _dbSqlReadTransactionOp,
        description: description,
      );
      // ignore: invalid_use_of_internal_member
      span?.origin = SentryTraceOrigins.autoDbSqfliteDatabase;
      setDatabaseAttributeData(span, dbName);

      var breadcrumb = Breadcrumb(
        message: description,
        category: _dbSqlReadTransactionOp,
        data: {},
        type: 'query',
      );
      setDatabaseAttributeOnBreadcrumb(breadcrumb, dbName);

      Future<T> newAction(Transaction txn) async {
        final executor = SentryDatabaseExecutor(
          txn,
          parentSpan: span,
          hub: _hub,
          dbName: dbName,
        );
        final sentrySqfliteTransaction =
            SentrySqfliteTransaction(executor, hub: _hub, dbName: dbName);

        return await action(sentrySqfliteTransaction);
      }

      try {
        final futureOrResult = _resolvedReadTransaction(newAction);
        T result;

        if (futureOrResult is Future<T>) {
          result = await futureOrResult;
        } else {
          result = futureOrResult;
        }

        span?.status = SpanStatus.ok();
        breadcrumb.data?['status'] = 'ok';

        return result;
      } catch (exception) {
        span?.throwable = exception;
        span?.status = SpanStatus.internalError();
        breadcrumb.data?['status'] = 'internal_error';
        breadcrumb = breadcrumb.copyWith(
          level: SentryLevel.warning,
        );

        rethrow;
      } finally {
        await span?.finish();

        // ignore: invalid_use_of_internal_member
        await _hub.scope.addBreadcrumb(breadcrumb);
      }
    });
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
