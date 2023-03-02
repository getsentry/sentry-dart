import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'package:sqflite/sqflite.dart';

// ignore: public_member_api_docs
class SentryDatabase implements Database {
  final Database _database;
  final Hub _hub;

  // ignore: public_member_api_docs
  SentryDatabase(
    this._database, {
    @internal Hub? hub,
  }) : _hub = hub ?? HubAdapter();

  @override
  Batch batch() {
    // TODO: implement batch
    return _database.batch();
  }

  @override
  Future<void> close() {
    Future<void> close() async {
      final currentSpan = _hub.getSpan();
      final span = currentSpan?.startChild(
        'db',
        description: 'close',
      );

      try {
        await _database.close();

        span?.status = SpanStatus.ok();
      } catch (exception) {
        span?.throwable = exception;
        span?.status = SpanStatus.internalError();

        rethrow;
      } finally {
        await span?.finish();
      }
    }

    return close();
  }

  @override
  Database get database => _database.database;

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) {
    Future<int> delete() async {
      final currentSpan = _hub.getSpan();
      final span = currentSpan?.startChild(
        'db.query.delete',
        description: 'delete', // TODO build description
      );

      try {
        final result =
            await _database.delete(table, where: where, whereArgs: whereArgs);

        span?.status = SpanStatus.ok();

        return result;
      } catch (exception) {
        span?.throwable = exception;
        span?.status = SpanStatus.internalError();

        rethrow;
      } finally {
        await span?.finish();
      }
    }

    return delete();
  }

  @override
  Future<T> devInvokeMethod<T>(String method, [Object? arguments]) {
    // ignore: deprecated_member_use
    return _database.devInvokeMethod(method, arguments);
  }

  @override
  Future<T> devInvokeSqlMethod<T>(String method, String sql,
      [List<Object?>? arguments]) {
    // ignore: deprecated_member_use
    return _database.devInvokeSqlMethod(method, sql);
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) {
    // TODO: implement execute
    throw UnimplementedError();
  }

  @override
  Future<int> insert(String table, Map<String, Object?> values,
      {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) {
    // TODO: implement insert
    throw UnimplementedError();
  }

  @override
  bool get isOpen => _database.isOpen;

  @override
  String get path => _database.path;

  @override
  Future<List<Map<String, Object?>>> query(String table,
      {bool? distinct,
      List<String>? columns,
      String? where,
      List<Object?>? whereArgs,
      String? groupBy,
      String? having,
      String? orderBy,
      int? limit,
      int? offset}) {
    // TODO: implement query
    throw UnimplementedError();
  }

  @override
  Future<QueryCursor> queryCursor(String table,
      {bool? distinct,
      List<String>? columns,
      String? where,
      List<Object?>? whereArgs,
      String? groupBy,
      String? having,
      String? orderBy,
      int? limit,
      int? offset,
      int? bufferSize}) {
    // TODO: implement queryCursor
    throw UnimplementedError();
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) {
    // TODO: implement rawDelete
    throw UnimplementedError();
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) {
    // TODO: implement rawInsert
    throw UnimplementedError();
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql,
      [List<Object?>? arguments]) {
    // TODO: implement rawQuery
    throw UnimplementedError();
  }

  @override
  Future<QueryCursor> rawQueryCursor(String sql, List<Object?>? arguments,
      {int? bufferSize}) {
    // TODO: implement rawQueryCursor
    throw UnimplementedError();
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) {
    // TODO: implement rawUpdate
    throw UnimplementedError();
  }

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action,
      {bool? exclusive}) {
    // TODO: implement transaction
    throw UnimplementedError();
  }

  @override
  Future<int> update(String table, Map<String, Object?> values,
      {String? where,
      List<Object?>? whereArgs,
      ConflictAlgorithm? conflictAlgorithm}) {
    // TODO: implement update
    throw UnimplementedError();
  }
}
