import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'package:sqflite/sqflite.dart';

// ignore: implementation_imports
import 'package:sqflite_common/src/sql_builder.dart';

import 'sentry_batch.dart';
import 'sentry_database.dart';
import 'utils/sentry_sqflite_span_helper.dart';

@internal
// ignore: public_member_api_docs
class SentryDatabaseExecutor implements DatabaseExecutor {
  final DatabaseExecutor _executor;
  final Object? _parentSpan;
  final String? _dbName;
  final Hub _hub;
  final SentrySqfliteSpanHelper _helper;

  // ignore: public_member_api_docs
  SentryDatabaseExecutor(
    this._executor, {
    Object? parentSpan,
    @internal Hub? hub,
    @internal String? dbName,
    // ignore: invalid_use_of_internal_member
    @internal SpanWrapper? spanWrapper,
  })  : _parentSpan = parentSpan,
        _hub = hub ?? HubAdapter(),
        _dbName = dbName,
        _helper = SentrySqfliteSpanHelper(
          spanWrapper: spanWrapper ??
              // ignore: invalid_use_of_internal_member
              (hub ?? HubAdapter()).options.spanWrapper,
          hub: hub ?? HubAdapter(),
          dbName: dbName,
        );

  @override
  Batch batch() => SentryBatch(_executor.batch(), hub: _hub, dbName: _dbName);

  @override
  Database get database => _executor.database;

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    final builder =
        SqlBuilder.delete(table, where: where, whereArgs: whereArgs);
    return _helper.wrapAsync<int>(
      operation: SentryDatabase.dbSqlExecuteOp,
      description: builder.sql,
      execute: () =>
          _executor.delete(table, where: where, whereArgs: whereArgs),
      // ignore: invalid_use_of_internal_member
      origin: SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      parentSpan: _parentSpan ?? _hub.getSpan(),
    );
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) {
    return _helper.wrapAsync<void>(
      operation: SentryDatabase.dbSqlExecuteOp,
      description: sql,
      execute: () => _executor.execute(sql, arguments),
      // ignore: invalid_use_of_internal_member
      origin: SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      parentSpan: _parentSpan ?? _hub.getSpan(),
    );
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    final builder = SqlBuilder.insert(
      table,
      values,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: conflictAlgorithm,
    );
    return _helper.wrapAsync<int>(
      operation: SentryDatabase.dbSqlExecuteOp,
      description: builder.sql,
      execute: () => _executor.insert(
        table,
        values,
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: conflictAlgorithm,
      ),
      // ignore: invalid_use_of_internal_member
      origin: SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      parentSpan: _parentSpan ?? _hub.getSpan(),
    );
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    final builder = SqlBuilder.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
      whereArgs: whereArgs,
    );
    return _helper.wrapAsync<List<Map<String, Object?>>>(
      operation: SentryDatabase.dbSqlQueryOp,
      description: builder.sql,
      execute: () => _executor.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      ),
      // ignore: invalid_use_of_internal_member
      origin: SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      parentSpan: _parentSpan ?? _hub.getSpan(),
    );
  }

  @override
  Future<QueryCursor> queryCursor(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int? bufferSize,
  }) {
    final builder = SqlBuilder.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
      whereArgs: whereArgs,
    );
    return _helper.wrapAsync<QueryCursor>(
      operation: SentryDatabase.dbSqlQueryOp,
      description: builder.sql,
      execute: () => _executor.queryCursor(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
        bufferSize: bufferSize,
      ),
      // ignore: invalid_use_of_internal_member
      origin: SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      parentSpan: _parentSpan ?? _hub.getSpan(),
    );
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) {
    return _helper.wrapAsync<int>(
      operation: SentryDatabase.dbSqlExecuteOp,
      description: sql,
      execute: () => _executor.rawDelete(sql, arguments),
      // ignore: invalid_use_of_internal_member
      origin: SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      parentSpan: _parentSpan ?? _hub.getSpan(),
    );
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) {
    return _helper.wrapAsync<int>(
      operation: SentryDatabase.dbSqlExecuteOp,
      description: sql,
      execute: () => _executor.rawInsert(sql, arguments),
      // ignore: invalid_use_of_internal_member
      origin: SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      parentSpan: _parentSpan ?? _hub.getSpan(),
    );
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    return _helper.wrapAsync<List<Map<String, Object?>>>(
      operation: SentryDatabase.dbSqlQueryOp,
      description: sql,
      execute: () => _executor.rawQuery(sql, arguments),
      // ignore: invalid_use_of_internal_member
      origin: SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      parentSpan: _parentSpan ?? _hub.getSpan(),
    );
  }

  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) {
    return _helper.wrapAsync<QueryCursor>(
      operation: SentryDatabase.dbSqlQueryOp,
      description: sql,
      execute: () => _executor.rawQueryCursor(
        sql,
        arguments,
        bufferSize: bufferSize,
      ),
      // ignore: invalid_use_of_internal_member
      origin: SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      parentSpan: _parentSpan ?? _hub.getSpan(),
    );
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) {
    return _helper.wrapAsync<int>(
      operation: SentryDatabase.dbSqlExecuteOp,
      description: sql,
      execute: () => _executor.rawUpdate(sql, arguments),
      // ignore: invalid_use_of_internal_member
      origin: SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      parentSpan: _parentSpan ?? _hub.getSpan(),
    );
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    final builder = SqlBuilder.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
    return _helper.wrapAsync<int>(
      operation: SentryDatabase.dbSqlExecuteOp,
      description: builder.sql,
      execute: () => _executor.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
        conflictAlgorithm: conflictAlgorithm,
      ),
      // ignore: invalid_use_of_internal_member
      origin: SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      parentSpan: _parentSpan ?? _hub.getSpan(),
    );
  }
}
