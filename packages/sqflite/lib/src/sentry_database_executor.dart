import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'package:sqflite/sqflite.dart';

// ignore: implementation_imports
import 'package:sqflite_common/src/sql_builder.dart';

import 'sentry_batch.dart';
import 'sentry_database.dart';
import 'utils/sentry_database_span_attributes.dart';

@internal
// ignore: public_member_api_docs
class SentryDatabaseExecutor implements DatabaseExecutor {
  final DatabaseExecutor _executor;
  // ignore: invalid_use_of_internal_member
  final InstrumentationSpan? _parentSpan;
  final String? _dbName;

  // ignore: public_member_api_docs
  SentryDatabaseExecutor(
    this._executor, {
    // ignore: invalid_use_of_internal_member
    InstrumentationSpan? parentSpan,
    @internal Hub? hub,
    @internal String? dbName,
  })  : _parentSpan = parentSpan,
        _hub = hub ?? HubAdapter(),
        _dbName = dbName {
    // ignore: invalid_use_of_internal_member
    _spanFactory = _hub.options.spanFactory;
  }

  final Hub _hub;

  // ignore: invalid_use_of_internal_member
  late final InstrumentationSpanFactory _spanFactory;

  // ignore: invalid_use_of_internal_member
  InstrumentationSpan? _getParent() {
    return _parentSpan ?? _spanFactory.getSpan(_hub);
  }

  @override
  Batch batch() => SentryBatch(_executor.batch(), hub: _hub, dbName: _dbName);

  @override
  Database get database => _executor.database;

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) {
    return Future<int>(() async {
      final parent = _getParent();
      final builder =
          SqlBuilder.delete(table, where: where, whereArgs: whereArgs);
      final span = _spanFactory.createSpan(
        parent,
        SentryDatabase.dbSqlExecuteOp,
        description: builder.sql,
      );
      // ignore: invalid_use_of_internal_member
      span?.origin = SentryTraceOrigins.autoDbSqfliteDatabaseExecutor;
      setDatabaseAttributeData(span, _dbName);

      final breadcrumb = Breadcrumb(
        message: builder.sql,
        category: SentryDatabase.dbSqlExecuteOp,
        data: {},
        type: 'query',
      );
      setDatabaseAttributeOnBreadcrumb(breadcrumb, _dbName);

      try {
        final result =
            await _executor.delete(table, where: where, whereArgs: whereArgs);

        span?.status = SpanStatus.ok();
        breadcrumb.data?['status'] = 'ok';

        return result;
      } catch (exception) {
        span?.throwable = exception;
        span?.status = SpanStatus.internalError();
        breadcrumb.data?['status'] = 'internal_error';
        breadcrumb.level = SentryLevel.warning;

        rethrow;
      } finally {
        await span?.finish();
        // ignore: invalid_use_of_internal_member
        await _hub.scope.addBreadcrumb(breadcrumb);
      }
    });
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) {
    return Future<void>(() async {
      final parent = _getParent();
      final span = _spanFactory.createSpan(
        parent,
        SentryDatabase.dbSqlExecuteOp,
        description: sql,
      );
      // ignore: invalid_use_of_internal_member
      span?.origin = SentryTraceOrigins.autoDbSqfliteDatabaseExecutor;
      setDatabaseAttributeData(span, _dbName);

      final breadcrumb = Breadcrumb(
        message: sql,
        category: SentryDatabase.dbSqlExecuteOp,
        data: {},
        type: 'query',
      );
      setDatabaseAttributeOnBreadcrumb(breadcrumb, _dbName);

      try {
        await _executor.execute(sql, arguments);

        span?.status = SpanStatus.ok();
        breadcrumb.data?['status'] = 'ok';
      } catch (exception) {
        span?.throwable = exception;
        span?.status = SpanStatus.internalError();
        breadcrumb.data?['status'] = 'internal_error';
        breadcrumb.level = SentryLevel.warning;

        rethrow;
      } finally {
        await span?.finish();
        // ignore: invalid_use_of_internal_member
        await _hub.scope.addBreadcrumb(breadcrumb);
      }
    });
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    return Future<int>(() async {
      final parent = _getParent();
      final builder = SqlBuilder.insert(
        table,
        values,
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: conflictAlgorithm,
      );
      final span = _spanFactory.createSpan(
        parent,
        SentryDatabase.dbSqlExecuteOp,
        description: builder.sql,
      );
      // ignore: invalid_use_of_internal_member
      span?.origin = SentryTraceOrigins.autoDbSqfliteDatabaseExecutor;
      setDatabaseAttributeData(span, _dbName);

      final breadcrumb = Breadcrumb(
        message: builder.sql,
        category: SentryDatabase.dbSqlExecuteOp,
        data: {},
        type: 'query',
      );
      setDatabaseAttributeOnBreadcrumb(breadcrumb, _dbName);

      try {
        final result = await _executor.insert(
          table,
          values,
          nullColumnHack: nullColumnHack,
          conflictAlgorithm: conflictAlgorithm,
        );

        span?.status = SpanStatus.ok();
        breadcrumb.data?['status'] = 'ok';

        return result;
      } catch (exception) {
        span?.throwable = exception;
        span?.status = SpanStatus.internalError();
        breadcrumb.data?['status'] = 'internal_error';
        breadcrumb.level = SentryLevel.warning;

        rethrow;
      } finally {
        await span?.finish();
        // ignore: invalid_use_of_internal_member
        await _hub.scope.addBreadcrumb(breadcrumb);
      }
    });
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
    return Future<List<Map<String, Object?>>>(() async {
      final parent = _getParent();
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
      final span = _spanFactory.createSpan(
        parent,
        SentryDatabase.dbSqlQueryOp,
        description: builder.sql,
      );
      // ignore: invalid_use_of_internal_member
      span?.origin = SentryTraceOrigins.autoDbSqfliteDatabaseExecutor;
      setDatabaseAttributeData(span, _dbName);

      final breadcrumb = Breadcrumb(
        message: builder.sql,
        category: SentryDatabase.dbSqlQueryOp,
        data: {},
        type: 'query',
      );
      setDatabaseAttributeOnBreadcrumb(breadcrumb, _dbName);

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
        breadcrumb.data?['status'] = 'ok';

        return result;
      } catch (exception) {
        span?.throwable = exception;
        span?.status = SpanStatus.internalError();
        breadcrumb.data?['status'] = 'internal_error';
        breadcrumb.level = SentryLevel.warning;

        rethrow;
      } finally {
        await span?.finish();
        // ignore: invalid_use_of_internal_member
        await _hub.scope.addBreadcrumb(breadcrumb);
      }
    });
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
    return Future<QueryCursor>(() async {
      final parent = _getParent();
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
      final span = _spanFactory.createSpan(
        parent,
        SentryDatabase.dbSqlQueryOp,
        description: builder.sql,
      );
      // ignore: invalid_use_of_internal_member
      span?.origin = SentryTraceOrigins.autoDbSqfliteDatabaseExecutor;
      setDatabaseAttributeData(span, _dbName);

      final breadcrumb = Breadcrumb(
        message: builder.sql,
        category: SentryDatabase.dbSqlQueryOp,
        data: {},
        type: 'query',
      );
      setDatabaseAttributeOnBreadcrumb(breadcrumb, _dbName);

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
        breadcrumb.data?['status'] = 'ok';

        return result;
      } catch (exception) {
        span?.throwable = exception;
        span?.status = SpanStatus.internalError();
        breadcrumb.data?['status'] = 'internal_error';
        breadcrumb.level = SentryLevel.warning;

        rethrow;
      } finally {
        await span?.finish();
        // ignore: invalid_use_of_internal_member
        await _hub.scope.addBreadcrumb(breadcrumb);
      }
    });
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) {
    return Future<int>(() async {
      final parent = _getParent();
      final span = _spanFactory.createSpan(
        parent,
        SentryDatabase.dbSqlExecuteOp,
        description: sql,
      );
      // ignore: invalid_use_of_internal_member
      span?.origin = SentryTraceOrigins.autoDbSqfliteDatabaseExecutor;
      setDatabaseAttributeData(span, _dbName);

      final breadcrumb = Breadcrumb(
        message: sql,
        category: SentryDatabase.dbSqlExecuteOp,
        data: {},
        type: 'query',
      );
      setDatabaseAttributeOnBreadcrumb(breadcrumb, _dbName);

      try {
        final result = await _executor.rawDelete(sql, arguments);

        span?.status = SpanStatus.ok();
        breadcrumb.data?['status'] = 'ok';

        return result;
      } catch (exception) {
        span?.throwable = exception;
        span?.status = SpanStatus.internalError();
        breadcrumb.data?['status'] = 'internal_error';
        breadcrumb.level = SentryLevel.warning;

        rethrow;
      } finally {
        await span?.finish();
        // ignore: invalid_use_of_internal_member
        await _hub.scope.addBreadcrumb(breadcrumb);
      }
    });
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) {
    return Future<int>(() async {
      final parent = _getParent();
      final span = _spanFactory.createSpan(
        parent,
        SentryDatabase.dbSqlExecuteOp,
        description: sql,
      );
      // ignore: invalid_use_of_internal_member
      span?.origin = SentryTraceOrigins.autoDbSqfliteDatabaseExecutor;
      setDatabaseAttributeData(span, _dbName);

      final breadcrumb = Breadcrumb(
        message: sql,
        category: SentryDatabase.dbSqlExecuteOp,
        data: {},
        type: 'query',
      );
      setDatabaseAttributeOnBreadcrumb(breadcrumb, _dbName);

      try {
        final result = await _executor.rawInsert(sql, arguments);

        span?.status = SpanStatus.ok();
        breadcrumb.data?['status'] = 'ok';

        return result;
      } catch (exception) {
        span?.throwable = exception;
        span?.status = SpanStatus.internalError();
        breadcrumb.data?['status'] = 'internal_error';
        breadcrumb.level = SentryLevel.warning;

        rethrow;
      } finally {
        await span?.finish();
        // ignore: invalid_use_of_internal_member
        await _hub.scope.addBreadcrumb(breadcrumb);
      }
    });
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    return Future<List<Map<String, Object?>>>(() async {
      final parent = _getParent();
      final span = _spanFactory.createSpan(
        parent,
        SentryDatabase.dbSqlQueryOp,
        description: sql,
      );
      // ignore: invalid_use_of_internal_member
      span?.origin = SentryTraceOrigins.autoDbSqfliteDatabaseExecutor;
      setDatabaseAttributeData(span, _dbName);

      final breadcrumb = Breadcrumb(
        message: sql,
        category: SentryDatabase.dbSqlQueryOp,
        data: {},
        type: 'query',
      );
      setDatabaseAttributeOnBreadcrumb(breadcrumb, _dbName);

      try {
        final result = await _executor.rawQuery(sql, arguments);

        span?.status = SpanStatus.ok();
        breadcrumb.data?['status'] = 'ok';

        return result;
      } catch (exception) {
        span?.throwable = exception;
        span?.status = SpanStatus.internalError();
        breadcrumb.data?['status'] = 'internal_error';
        breadcrumb.level = SentryLevel.warning;

        rethrow;
      } finally {
        await span?.finish();
        // ignore: invalid_use_of_internal_member
        await _hub.scope.addBreadcrumb(breadcrumb);
      }
    });
  }

  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) {
    return Future<QueryCursor>(() async {
      final parent = _getParent();
      final span = _spanFactory.createSpan(
        parent,
        SentryDatabase.dbSqlQueryOp,
        description: sql,
      );
      // ignore: invalid_use_of_internal_member
      span?.origin = SentryTraceOrigins.autoDbSqfliteDatabaseExecutor;
      setDatabaseAttributeData(span, _dbName);

      final breadcrumb = Breadcrumb(
        message: sql,
        category: SentryDatabase.dbSqlQueryOp,
        data: {},
        type: 'query',
      );
      setDatabaseAttributeOnBreadcrumb(breadcrumb, _dbName);

      try {
        final result = await _executor.rawQueryCursor(
          sql,
          arguments,
          bufferSize: bufferSize,
        );

        span?.status = SpanStatus.ok();
        breadcrumb.data?['status'] = 'ok';

        return result;
      } catch (exception) {
        span?.throwable = exception;
        span?.status = SpanStatus.internalError();
        breadcrumb.data?['status'] = 'internal_error';
        breadcrumb.level = SentryLevel.warning;

        rethrow;
      } finally {
        await span?.finish();
        // ignore: invalid_use_of_internal_member
        await _hub.scope.addBreadcrumb(breadcrumb);
      }
    });
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) {
    return Future<int>(() async {
      final parent = _getParent();
      final span = _spanFactory.createSpan(
        parent,
        SentryDatabase.dbSqlExecuteOp,
        description: sql,
      );
      // ignore: invalid_use_of_internal_member
      span?.origin = SentryTraceOrigins.autoDbSqfliteDatabaseExecutor;
      setDatabaseAttributeData(span, _dbName);

      final breadcrumb = Breadcrumb(
        message: sql,
        category: SentryDatabase.dbSqlExecuteOp,
        data: {},
        type: 'query',
      );
      setDatabaseAttributeOnBreadcrumb(breadcrumb, _dbName);

      try {
        final result = await _executor.rawUpdate(sql, arguments);

        span?.status = SpanStatus.ok();
        breadcrumb.data?['status'] = 'ok';

        return result;
      } catch (exception) {
        span?.throwable = exception;
        span?.status = SpanStatus.internalError();
        breadcrumb.data?['status'] = 'internal_error';
        breadcrumb.level = SentryLevel.warning;

        rethrow;
      } finally {
        await span?.finish();
        // ignore: invalid_use_of_internal_member
        await _hub.scope.addBreadcrumb(breadcrumb);
      }
    });
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    return Future<int>(() async {
      final parent = _getParent();
      final builder = SqlBuilder.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
        conflictAlgorithm: conflictAlgorithm,
      );
      final span = _spanFactory.createSpan(
        parent,
        SentryDatabase.dbSqlExecuteOp,
        description: builder.sql,
      );
      // ignore: invalid_use_of_internal_member
      span?.origin = SentryTraceOrigins.autoDbSqfliteDatabaseExecutor;
      setDatabaseAttributeData(span, _dbName);

      final breadcrumb = Breadcrumb(
        message: builder.sql,
        category: SentryDatabase.dbSqlExecuteOp,
        data: {},
        type: 'query',
      );
      setDatabaseAttributeOnBreadcrumb(breadcrumb, _dbName);

      try {
        final result = await _executor.update(
          table,
          values,
          where: where,
          whereArgs: whereArgs,
          conflictAlgorithm: conflictAlgorithm,
        );

        span?.status = SpanStatus.ok();
        breadcrumb.data?['status'] = 'ok';

        return result;
      } catch (exception) {
        span?.throwable = exception;
        span?.status = SpanStatus.internalError();
        breadcrumb.data?['status'] = 'internal_error';
        breadcrumb.level = SentryLevel.warning;

        rethrow;
      } finally {
        await span?.finish();
        // ignore: invalid_use_of_internal_member
        await _hub.scope.addBreadcrumb(breadcrumb);
      }
    });
  }
}
