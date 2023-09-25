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
  return Future<Database>(() async {
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
    final description = 'Open DB: $path';
    final span = currentSpan?.startChild(
      SentryDatabase.dbOp,
      description: description,
    );
    // ignore: invalid_use_of_internal_member
    span?.origin = SentryTraceOrigins.autoDbSqfliteOpenDatabase;

    final Map<String, dynamic> breadcrumbData = {};

    try {
      final database =
          await databaseFactory.openDatabase(path, options: dbOptions);

      final sentryDatabase = SentryDatabase(database, hub: newHub);

      span?.status = SpanStatus.ok();
      breadcrumbData['status'] = 'ok';

      return sentryDatabase;
    } catch (exception) {
      span?.throwable = exception;
      span?.status = SpanStatus.internalError();
      breadcrumbData['status'] = 'internalError';

      rethrow;
    } finally {
      await span?.finish();

      final breadcrumb = Breadcrumb(
        message: description,
        category: SentryDatabase.dbOp,
        data: breadcrumbData,
      );
      // ignore: invalid_use_of_internal_member
      await newHub.scope.addBreadcrumb(breadcrumb);
    }
  });
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
