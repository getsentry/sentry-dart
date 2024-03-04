import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'package:sqflite/sqflite.dart';

import 'sentry_batch.dart';

/// A [Transaction] wrapper that adds Sentry support.
///
/// ```dart
/// import 'package:sqflite/sqflite.dart';
/// import 'package:sentry_sqflite/sentry_sqflite.dart';
///
/// final database = await openDatabase('path/to/db');
/// final sentryDatabase = SentryDatabase(database);
///
/// await sentryDatabase.transaction((txn) async {
/// ...
/// });
/// ```
@experimental
class SentrySqfliteTransaction extends Transaction implements DatabaseExecutor {
  final DatabaseExecutor _executor;
  final Hub _hub;
  final String? _dbName;

  @internal
  // ignore: public_member_api_docs
  SentrySqfliteTransaction(
    this._executor, {
    @internal Hub? hub,
    @internal String? dbName,
  })  : _hub = hub ?? HubAdapter(),
        _dbName = dbName;

  @override
  Batch batch() => SentryBatch(_executor.batch(), hub: _hub, dbName: _dbName);

  @override
  Database get database => _executor.database;

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) =>
      _executor.delete(
        table,
        where: where,
        whereArgs: whereArgs,
      );

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) =>
      _executor.execute(sql, arguments);

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      _executor.insert(
        table,
        values,
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: conflictAlgorithm,
      );

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
  }) =>
      _executor.query(
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
      );

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
  }) =>
      _executor.queryCursor(
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
      );

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) =>
      _executor.rawDelete(sql, arguments);

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) =>
      _executor.rawInsert(sql, arguments);

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) =>
      _executor.rawQuery(sql, arguments);

  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) =>
      _executor.rawQueryCursor(sql, arguments, bufferSize: bufferSize);

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) =>
      _executor.rawUpdate(sql, arguments);

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      _executor.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
        conflictAlgorithm: conflictAlgorithm,
      );
}
