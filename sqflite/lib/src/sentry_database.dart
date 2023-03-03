import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'package:sqflite/sqflite.dart';

// ignore: implementation_imports
import 'package:sqflite_common/src/sql_builder.dart';

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
    // TODO: implement batch, needs a wrapper
    return _database.batch();
  }

  @override
  Future<void> close() {
    Future<void> future() async {
      final currentSpan = _hub.getSpan();
      final span = currentSpan?.startChild(
        'db',
        description: 'CLOSE',
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

    return future();
  }

  @override
  Database get database => _database.database;

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) {
    Future<int> future() async {
      final currentSpan = _hub.getSpan();
      final builder =
          SqlBuilder.delete(table, where: where, whereArgs: whereArgs);
      final span = currentSpan?.startChild(
        'db.sql.execute',
        description: builder.sql,
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

    return future();
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
    Future<void> future() async {
      final currentSpan = _hub.getSpan();
      final span = currentSpan?.startChild(
        'db.sql.execute',
        description: sql,
      );

      try {
        await _database.execute(sql, arguments);

        span?.status = SpanStatus.ok();
      } catch (exception) {
        span?.throwable = exception;
        span?.status = SpanStatus.internalError();

        rethrow;
      } finally {
        await span?.finish();
      }
    }

    return future();
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    Future<int> future() async {
      final currentSpan = _hub.getSpan();
      final builder = SqlBuilder.insert(
        table,
        values,
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: conflictAlgorithm,
      );
      final span = currentSpan?.startChild(
        'db.sql.execute',
        description: builder.sql,
      );

      try {
        final result = await _database.insert(
          table,
          values,
          nullColumnHack: nullColumnHack,
          conflictAlgorithm: conflictAlgorithm,
        );

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

    return future();
  }

  @override
  bool get isOpen => _database.isOpen;

  @override
  String get path => _database.path;

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
    Future<List<Map<String, Object?>>> future() async {
      final currentSpan = _hub.getSpan();
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
      final span = currentSpan?.startChild(
        'db.sql.query',
        description: builder.sql,
      );

      try {
        final result = await _database.query(
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

    return future();
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
    Future<QueryCursor> future() async {
      final currentSpan = _hub.getSpan();
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
      final span = currentSpan?.startChild(
        'db.sql.query',
        description: builder.sql,
      );

      try {
        final result = await _database.queryCursor(
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

    return future();
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) {
    Future<int> future() async {
      final currentSpan = _hub.getSpan();
      final span = currentSpan?.startChild(
        'db.sql.execute',
        description: sql,
      );

      try {
        final result = await _database.rawDelete(sql, arguments);

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

    return future();
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) {
    Future<int> future() async {
      final currentSpan = _hub.getSpan();
      final span = currentSpan?.startChild(
        'db.sql.execute',
        description: sql,
      );

      try {
        final result = await _database.rawInsert(sql, arguments);

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

    return future();
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    Future<List<Map<String, Object?>>> future() async {
      final currentSpan = _hub.getSpan();
      final span = currentSpan?.startChild(
        'db.sql.query',
        description: sql,
      );

      try {
        final result = await _database.rawQuery(sql, arguments);

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

    return future();
  }

  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) {
    Future<QueryCursor> future() async {
      final currentSpan = _hub.getSpan();
      final span = currentSpan?.startChild(
        'db.sql.query',
        description: sql,
      );

      try {
        final result = await _database.rawQueryCursor(
          sql,
          arguments,
          bufferSize: bufferSize,
        );

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

    return future();
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) {
    Future<int> future() async {
      final currentSpan = _hub.getSpan();
      final span = currentSpan?.startChild(
        'db.sql.execute',
        description: sql,
      );

      try {
        final result = await _database.rawUpdate(sql, arguments);

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

    return future();
  }

  // TODO: implement transaction, needs a wrapper as well (DatabaseExecutor)
  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) =>
      _database.transaction(action, exclusive: exclusive);

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    Future<int> future() async {
      final currentSpan = _hub.getSpan();
      final builder = SqlBuilder.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
        conflictAlgorithm: conflictAlgorithm,
      );
      final span = currentSpan?.startChild(
        'db.sql.execute',
        description: builder.sql,
      );

      try {
        final result = await _database.update(
          table,
          values,
          where: where,
          whereArgs: whereArgs,
          conflictAlgorithm: conflictAlgorithm,
        );

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

    return future();
  }
}
