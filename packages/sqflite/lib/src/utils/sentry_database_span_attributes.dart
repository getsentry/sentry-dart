import 'package:sentry/sentry.dart';

import '../../sentry_sqflite.dart';

/// Sets the database attributes on the [breadcrumb].
/// It contains the database system and the database name.
void setDatabaseAttributeOnBreadcrumb(Breadcrumb breadcrumb, String? dbName) {
  breadcrumb.data?[SentryDatabase.dbSystemKey] = SentryDatabase.dbSystem;
  if (dbName != null) {
    breadcrumb.data?[SentryDatabase.dbNameKey] = dbName;
  }
}
