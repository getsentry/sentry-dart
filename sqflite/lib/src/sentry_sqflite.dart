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

    // ignore: invalid_use_of_internal_member
    final options = (hub ?? HubAdapter()).options;

    final database =
        await databaseFactory.openDatabase(path, options: dbOptions);

    if (!options.isTracingEnabled()) {
      return database;
    }

    return SentryDatabase(database);
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
Future<Database> openReadOnlyDatabaseWithSentry(
  String path, {
  @internal Hub? hub,
}) {
  return openDatabaseWithSentry(path, readOnly: true, hub: hub);
}
