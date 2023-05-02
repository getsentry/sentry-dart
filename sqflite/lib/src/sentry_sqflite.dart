import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'package:sqflite/sqflite.dart';

import 'sentry_database.dart';

/// Opens a database with Sentry support.
///
/// ```dart
/// import 'package:sqflite/sqflite.dart';
/// import 'package:sentry_sqflite/sentry_sqflite.dart';
///
/// final database = await openDatabaseWithSentry('path/to/db');
/// ```
@experimental
Future<Database> openDatabaseWithSentry(
  String path, {
  int? version,
  OnDatabaseConfigureFn? onConfigure,
  OnDatabaseCreateFn? onCreate,
  OnDatabaseVersionChangeFn? onUpgrade,
  OnDatabaseVersionChangeFn? onDowngrade,
  OnDatabaseOpenFn? onOpen,
  bool readOnly = false,
  bool singleInstance = true,
  @internal Hub? hub,
}) {
  Future<Database> openDatabase() async {
    final dbOptions = OpenDatabaseOptions(
      version: version,
      onConfigure: onConfigure,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
      onDowngrade: onDowngrade,
      onOpen: onOpen,
      readOnly: readOnly,
      singleInstance: singleInstance,
    );

    final newHub = hub ?? HubAdapter();

    final currentSpan = newHub.getSpan();
    final span = currentSpan?.startChild(
      SentryDatabase.dbOp,
      description: 'Open DB: $path',
    );

    try {
      final database =
          await databaseFactory.openDatabase(path, options: dbOptions);

      final sentryDatabase = SentryDatabase(database, hub: newHub);

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

/// Opens a database with Sentry support.
///
/// ```dart
/// import 'package:sqflite/sqflite.dart';
/// import 'package:sentry_sqflite/sentry_sqflite.dart';
///
/// final database = await openReadOnlyDatabaseWithSentry('path/to/db');
/// ```
@experimental
Future<Database> openReadOnlyDatabaseWithSentry(
  String path, {
  @internal Hub? hub,
}) {
  return openDatabaseWithSentry(path, readOnly: true, hub: hub);
}
