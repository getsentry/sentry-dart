import 'dart:async';

import 'package:drift/backends.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'sentry_span_helper.dart';

/// Signature of a function that opens a database connection when instructed to.
typedef DatabaseOpener = FutureOr<QueryExecutor> Function();

/// Sentry Drift Database Executor based on [LazyDatabase].
///
/// A special database executor that delegates work to another [QueryExecutor].
/// The other executor is lazily opened by a [DatabaseOpener].
class SentryDriftDatabase extends LazyDatabase {
  final Hub _hub;
  final _spanHelper = SentrySpanHelper(
    // ignore: invalid_use_of_internal_member
    SentryTraceOrigins.autoDbDriftDatabaseExecutor,
  );

  String? dbName = 'people-drift-impl';

  @internal
  // ignore: public_member_api_docs
  static const dbNameKey = 'db.name';

  @internal
  // ignore: public_member_api_docs
  static const dbOp = 'db';

  @internal
  // ignore: public_member_api_docs
  static const dbSystemKey = 'db.system';

  @internal
  // ignore: public_member_api_docs
  static const dbSystem = 'sqlite';

  /// Declares a [SentryDriftDatabase] that will run [opener] when the database is
  /// first requested to be opened. You must specify the same [dialect] as the
  /// underlying database has
  SentryDriftDatabase(
    super.opener, {
    super.dialect,
    @internal Hub? hub,
  })  : _hub = hub ?? HubAdapter() {
    _spanHelper.setHub(_hub);
  }

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) {
    return _spanHelper.asyncWrapInSpan('open', () async {
      return await super.ensureOpen(user);
    });
  }

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) {
    return _spanHelper.asyncWrapInSpan('custom', () async {
      return await super.runCustom(statement, args);
    }, dbName: dbName);
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) {
    return _spanHelper.asyncWrapInSpan('delete', () async {
      return await super.runDelete(statement, args);
    }, dbName: dbName);
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) {
    return _spanHelper.asyncWrapInSpan('insert', () async {
      return await super.runInsert(statement, args);
    }, dbName: dbName);
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
      String statement, List<Object?> args) {
    return _spanHelper.asyncWrapInSpan('select', () async {
      return await super.runSelect(statement, args);
    }, dbName: dbName);
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) {
    return _spanHelper.asyncWrapInSpan('update', () async {
      return await super.runUpdate(statement, args);
    }, dbName: dbName);
  }

  @override
  Future<void> close() {
    return _spanHelper.asyncWrapInSpan('close', () async {
      return await super.close();
    }, dbName: dbName);
  }
}
