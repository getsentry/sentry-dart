import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'package:sqflite/sqflite.dart';

import 'sentry_database_executor.dart';
import 'sentry_sqflite_transaction.dart';
import 'version.dart';

/// A [Database] wrapper that adds Sentry support.
///
/// ```dart
/// import 'package:sqflite/sqflite.dart';
/// import 'package:sentry_sqflite/sentry_sqflite.dart';
///
/// final database = await openDatabase('path/to/db');
/// final sentryDatabase = SentryDatabase(database);
/// ```
class SentryDatabase extends SentryDatabaseExecutor implements Database {
  final Database _database;
  final Hub _hub;

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
        super(_database, hub: hub) {
    
    // ignore: invalid_use_of_internal_member
    final options = _hub.options;
    options.sdk.addIntegration('SentrySqfliteTracing');
    options.sdk.addPackage(packageName, sdkVersion);
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
    Future<T> future() async {
      final currentSpan = _hub.getSpan();
      final span = currentSpan?.startChild(
        'db',
        description: 'TRANSACTION',
      );

      Future<T> newAction(Transaction txn) async {
        final sentryExecutor =
            SentryDatabaseExecutor(txn, parentSpan: span, hub: _hub);
        final sentrySqfliteTransaction =
            SentrySqfliteTransaction(sentryExecutor, hub: _hub);

        return await action(sentrySqfliteTransaction);
      }

      try {
        final result =
            await _database.transaction(newAction, exclusive: exclusive);

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
