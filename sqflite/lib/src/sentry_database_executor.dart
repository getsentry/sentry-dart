import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'package:sqflite/sqflite.dart';

// ignore: implementation_imports
import 'package:sqflite_common/src/sql_builder.dart';

import 'sentry_batch.dart';

@internal
// ignore: public_member_api_docs
class SentryDatabaseExecutor implements DatabaseExecutor {
  final DatabaseExecutor _executor;
  final ISentrySpan? _parentSpan;

  // ignore: public_member_api_docs
  SentryDatabaseExecutor(
    this._executor, {
    ISentrySpan? parentSpan,
    @internal Hub? hub,
  })  : _parentSpan = parentSpan,
        _hub = hub ?? HubAdapter();
  final Hub _hub;

  @override
  Batch batch() => SentryBatch(_executor.batch(), hub: _hub);

  @override
  Database get database => _executor.database;

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) {
    Future<int> future() async {
      final currentSpan = _parentSpan ?? _hub.getSpan();
      final builder =
          SqlBuilder.delete(table, where: where, whereArgs: whereArgs);
      final span = currentSpan?.startChild(
        'db.sql.execute',
        description: builder.sql,
      );

      try {
        final result =
            await _executor.delete(table, where: where, whereArgs: whereArgs);

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
  Future<void> execute(String sql, [List<Object?>? arguments]) {
    Future<void> future() async {
      final currentSpan = _parentSpan ?? _hub.getSpan();
      final span = currentSpan?.startChild(
        'db.sql.execute',
        description: sql,
      );

      try {
        await _executor.execute(sql, arguments);

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
      final currentSpan = _parentSpan ?? _hub.getSpan();
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
        final result = await _executor.insert(
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
      final currentSpan = _parentSpan ?? _hub.getSpan();
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
        final result = await _executor.query(
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
      final currentSpan = _parentSpan ?? _hub.getSpan();
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
        final result = await _executor.queryCursor(
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
      final currentSpan = _parentSpan ?? _hub.getSpan();
      final span = currentSpan?.startChild(
        'db.sql.execute',
        description: sql,
      );

      try {
        final result = await _executor.rawDelete(sql, arguments);

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
      final currentSpan = _parentSpan ?? _hub.getSpan();
      final span = currentSpan?.startChild(
        'db.sql.execute',
        description: sql,
      );

      try {
        final result = await _executor.rawInsert(sql, arguments);

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
      final currentSpan = _parentSpan ?? _hub.getSpan();
      final span = currentSpan?.startChild(
        'db.sql.query',
        description: sql,
      );

      try {
        final result = await _executor.rawQuery(sql, arguments);

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
      final currentSpan = _parentSpan ?? _hub.getSpan();
      final span = currentSpan?.startChild(
        'db.sql.query',
        description: sql,
      );

      try {
        final result = await _executor.rawQueryCursor(
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
      final currentSpan = _parentSpan ?? _hub.getSpan();
      final span = currentSpan?.startChild(
        'db.sql.execute',
        description: sql,
      );

      try {
        final result = await _executor.rawUpdate(sql, arguments);

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
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    Future<int> future() async {
      final currentSpan = _parentSpan ?? _hub.getSpan();
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
        final result = await _executor.update(
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
