import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'package:sqflite/sqflite.dart';
// ignore: implementation_imports
import 'package:sqflite_common/src/factory_mixin.dart';
// ignore: implementation_imports
import 'package:sqflite/src/sqflite_impl.dart' as impl;

import 'sentry_database.dart';

/// Using this factory, all [Database] instances will be wrapped with Sentry.
///
/// ```dart
/// import 'package:sqflite/sqflite.dart';
///
/// databaseFactory = SentrySqfliteDatabaseFactory();
///
/// final database = await openDatabase('path/to/db');
/// ```
class SentrySqfliteDatabaseFactory with SqfliteDatabaseFactoryMixin {
  /// ```dart
  /// import 'package:sqflite/sqflite.dart';
  ///
  /// databaseFactory = SentrySqfliteDatabaseFactory();
  ///
  /// final database = await openDatabase('path/to/db');
  /// ```
  SentrySqfliteDatabaseFactory({@internal Hub? hub})
      : _hub = hub ?? HubAdapter();

  final Hub _hub;

  @override
  Future<T> invokeMethod<T>(String method, [Object? arguments]) =>
      impl.invokeMethod(method, arguments);

  @override
  Future<Database> openDatabase(
    String path, {
    OpenDatabaseOptions? options,
  }) async {
    // ignore: invalid_use_of_internal_member
    if (!_hub.options.isTracingEnabled()) {
      return super.openDatabase(path, options: options);
    }

    Future<Database> openDatabase() async {
      final currentSpan = _hub.getSpan();
      final span = currentSpan?.startChild(
        'db',
        description: 'OPEN',
      );

      try {
        final database = await super.openDatabase(path, options: options);

        final sentryDatabase = SentryDatabase(database, hub: _hub);

        span?.status = SpanStatus.ok();
        return sentryDatabase;
      } catch (exception) {
        span?.throwable = exception;
        span?.status = SpanStatus.internalError();

        rethrow;
      } finally {
        await span?.finish();
      }
    }

    return openDatabase();
  }
}
