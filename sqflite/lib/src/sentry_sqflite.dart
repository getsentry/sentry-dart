import 'package:sqflite/sqflite.dart';

import 'sentry_database.dart';

Future<Database> openDatabase(
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
