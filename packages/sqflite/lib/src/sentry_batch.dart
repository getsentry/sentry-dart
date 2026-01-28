import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'package:sqflite/sqflite.dart';

// ignore: implementation_imports
import 'package:sqflite_common/src/sql_builder.dart';

import 'sentry_database.dart';
import 'utils/sentry_database_span_attributes.dart';

/// A [Batch] wrapper that adds Sentry support.
///
/// ```dart
/// import 'package:sqflite/sqflite.dart';
/// import 'package:sentry_sqflite/sentry_sqflite.dart';
///
/// final database = await openDatabase('path/to/db');
/// final sentryDatabase = SentryDatabase(database);
/// final batch = sentryDatabase.batch();
/// ```
@experimental
class SentryBatch implements Batch {
  final Batch _batch;
  final Hub _hub;
  final String? _dbName;

  // we don't clear the buffer because SqfliteBatch don't either
  final _buffer = StringBuffer();

  // ignore: invalid_use_of_internal_member
  late final InstrumentationSpanFactory _spanFactory;

  /// ```dart
  /// import 'package:sqflite/sqflite.dart';
  /// import 'package:sentry_sqflite/sentry_sqflite.dart';
  ///
  /// final database = await openDatabase('path/to/db');
  /// final sentryDatabase = SentryDatabase(database);
  /// final batch = sentryDatabase.batch();
  /// ```
  SentryBatch(
    this._batch, {
    @internal Hub? hub,
    @internal String? dbName,
  })  : _hub = hub ?? HubAdapter(),
        _dbName = dbName {
    // ignore: invalid_use_of_internal_member
    _spanFactory = _hub.options.spanFactory;
  }

  @override
  Future<List<Object?>> apply({bool? noResult, bool? continueOnError}) {
    return Future<List<Object?>>(() async {
      final parent = _spanFactory.getSpan(_hub);

      final span = _spanFactory.createChildSpan(
        parent,
        SentryDatabase.dbOp,
        description: _buffer.toString().trim(),
      );

      // ignore: invalid_use_of_internal_member
      span?.origin = SentryTraceOrigins.autoDbSqfliteBatch;
      setDatabaseAttributeDataOnInstrumentationSpan(span, _dbName);

      final breadcrumb = Breadcrumb(
        message: _buffer.toString().trim(),
        data: {},
        type: 'query',
      );
      setDatabaseAttributeOnBreadcrumb(breadcrumb, _dbName);

      try {
        final result = await _batch.apply(
          noResult: noResult,
          continueOnError: continueOnError,
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

  /// @nodoc Disable dart doc warnings inherited from [Batch]
  @override
  Future<List<Object?>> commit({
    bool? exclusive,
    bool? noResult,
    bool? continueOnError,
  }) {
    return Future<List<Object?>>(() async {
      final parent = _spanFactory.getSpan(_hub);

      final span = _spanFactory.createChildSpan(
        parent,
        SentryDatabase.dbOp,
        description: _buffer.toString().trim(),
      );
      // ignore: invalid_use_of_internal_member
      span?.origin = SentryTraceOrigins.autoDbSqfliteBatch;
      setDatabaseAttributeDataOnInstrumentationSpan(span, _dbName);

      final breadcrumb = Breadcrumb(
        message: _buffer.toString().trim(),
        data: {},
        type: 'query',
      );
      setDatabaseAttributeOnBreadcrumb(breadcrumb, _dbName);

      try {
        final result = await _batch.commit(
          exclusive: exclusive,
          noResult: noResult,
          continueOnError: continueOnError,
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
  void delete(String table, {String? where, List<Object?>? whereArgs}) {
    final builder =
        SqlBuilder.delete(table, where: where, whereArgs: whereArgs);
    _buffer.writeln(builder.sql);

    _batch.delete(table, where: where, whereArgs: whereArgs);
  }

  @override
  void execute(String sql, [List<Object?>? arguments]) {
    _buffer.writeln(sql);

    _batch.execute(sql, arguments);
  }

  @override
  void insert(
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
    _buffer.writeln(builder.sql);

    _batch.insert(
      table,
      values,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  @override
  int get length => _batch.length;

  @override
  void query(
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
    _buffer.writeln(builder.sql);

    _batch.query(
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
  }

  @override
  void rawDelete(String sql, [List<Object?>? arguments]) {
    _buffer.writeln(sql);

    _batch.rawDelete(sql, arguments);
  }

  @override
  void rawInsert(String sql, [List<Object?>? arguments]) {
    _buffer.writeln(sql);

    _batch.rawInsert(sql, arguments);
  }

  @override
  void rawQuery(String sql, [List<Object?>? arguments]) {
    _buffer.writeln(sql);

    _batch.rawQuery(sql, arguments);
  }

  @override
  void rawUpdate(String sql, [List<Object?>? arguments]) {
    _buffer.writeln(sql);

    _batch.rawUpdate(sql, arguments);
  }

  @override
  void update(
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
    _buffer.writeln(builder.sql);

    _batch.update(
      table,
      where: where,
      values,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
  }
}
