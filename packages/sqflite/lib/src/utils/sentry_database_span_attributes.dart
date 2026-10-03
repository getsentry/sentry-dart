import 'package:sentry/sentry.dart';

import '../../sentry_sqflite.dart';

/// Returns the database attributes known when a span is created.
Map<String, dynamic> databaseSpanData(String? dbName) => {
      SentryDatabase.dbSystemKey: SentryDatabase.dbSystem,
      if (dbName != null) SentryDatabase.dbNameKey: dbName,
    };

/// Sets the database attributes on the [breadcrumb].
/// It contains the database system and the database name.
void setDatabaseAttributeOnBreadcrumb(Breadcrumb breadcrumb, String? dbName) {
  breadcrumb.data?[SentryDatabase.dbSystemKey] = SentryDatabase.dbSystem;
  if (dbName != null) {
    breadcrumb.data?[SentryDatabase.dbNameKey] = dbName;
  }
}
