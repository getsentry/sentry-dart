import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'package:sqflite/sqflite.dart';

import 'sentry_database.dart';
import 'utils/sentry_sqflite_span_helper.dart';

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
}) async {
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

  final helper = SentrySqfliteSpanHelper(
    // ignore: invalid_use_of_internal_member
    spanWrapper: newHub.options.spanWrapper,
    hub: newHub,
  );

  return helper.wrapAsync<Database>(
    operation: SentryDatabase.dbOp,
    description: 'Open DB: $path',
    execute: () async {
      final database =
          await databaseFactory.openDatabase(path, options: dbOptions);
      return SentryDatabase(database, hub: newHub);
    },
    // ignore: invalid_use_of_internal_member
    origin: SentryTraceOrigins.autoDbSqfliteOpenDatabase,
    parentSpan: newHub.getSpan(),
  );
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
