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
}) {
  Future<Database> openDatabase() async {
    final options = OpenDatabaseOptions(
      version: version,
      onConfigure: onConfigure,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
      onDowngrade: onDowngrade,
      onOpen: onOpen,
      readOnly: readOnly,
      singleInstance: singleInstance,
    );
    final database = await databaseFactory.openDatabase(path, options: options);

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
Future<Database> openReadOnlyDatabaseWithSentry(String path) {
  return openDatabaseWithSentry(path, readOnly: true);
}
