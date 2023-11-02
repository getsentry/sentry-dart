import 'dart:async';

import 'package:drift/backends.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'sentry_span_helper.dart';

/// Signature of a function that opens a database connection when instructed to.
typedef DatabaseOpener = FutureOr<QueryExecutor> Function();

/// Sentry Drift Database Executor based on [LazyDatabase].
///
/// A special database executor that delegates work to another [QueryExecutor].
/// The other executor is lazily opened by a [DatabaseOpener].
class SentryDriftDatabase extends QueryExecutor {
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

  /// Underlying executor
  late final QueryExecutor _delegate;

  bool _delegateAvailable = false;
  final SqlDialect _dialect;

  Completer<void>? _openDelegate;

  @override
  SqlDialect get dialect {
    // Drift reads dialect before database opened, so we must know in advance
    if (_delegateAvailable && _dialect != _delegate.dialect) {
      throw Exception('LazyDatabase created with $_dialect, but underlying '
          'database is ${_delegate.dialect}.');
    }
    return _dialect;
  }

  /// The function that will open the database when this [SentryDriftDatabase] gets
  /// opened for the first time.
  final DatabaseOpener opener;

  /// Declares a [SentryDriftDatabase] that will run [opener] when the database is
  /// first requested to be opened. You must specify the same [dialect] as the
  /// underlying database has
  SentryDriftDatabase(
    this.opener, {
    SqlDialect dialect = SqlDialect.sqlite,
    @internal Hub? hub,
  })  : _dialect = dialect,
        _hub = hub ?? HubAdapter() {
    _spanHelper.setHub(_hub);
  }

  Future<void> _awaitOpened() {
    return _spanHelper.asyncWrapInSpan('open', () async {
      if (_delegateAvailable) {
        return Future.value();
      } else if (_openDelegate != null) {
        return _openDelegate!.future;
      } else {
        final delegate = _openDelegate = Completer();
        await Future.sync(opener).then((database) {
          _delegate = database;
          _delegateAvailable = true;
          delegate.complete();
        }, onError: delegate.completeError);
        return delegate.future;
      }
    }, dbName: dbName);
  }

  @override
  TransactionExecutor beginTransaction() {
    final a = _delegate.beginTransaction();
    return _delegate.beginTransaction();
  }

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) {
    return _awaitOpened().then((_) => _delegate.ensureOpen(user));
  }

  @override
  Future<void> runBatched(BatchedStatements statements) {
    return _delegate.runBatched(statements);
  }

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) {
    return _spanHelper.asyncWrapInSpan('custom', () async {
      return await _delegate.runCustom(statement, args);
    }, dbName: dbName);
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) {
    return _spanHelper.asyncWrapInSpan('delete', () async {
      return await _delegate.runDelete(statement, args);
    }, dbName: dbName);
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) {
    return _spanHelper.asyncWrapInSpan('insert', () async {
      return await _delegate.runInsert(statement, args);
    }, dbName: dbName);
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
      String statement, List<Object?> args) {
    return _spanHelper.asyncWrapInSpan('select', () async {
      return await _delegate.runSelect(statement, args);
    }, dbName: dbName);
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) {
    return _spanHelper.asyncWrapInSpan('update', () async {
      return await _delegate.runUpdate(statement, args);
    }, dbName: dbName);
  }

  @override
  Future<void> close() {
    return _spanHelper.asyncWrapInSpan('close', () async {
      if (_delegateAvailable) {
        return _delegate.close();
      } else {
        return Future.value();
      }
    }, dbName: dbName);
  }
}
