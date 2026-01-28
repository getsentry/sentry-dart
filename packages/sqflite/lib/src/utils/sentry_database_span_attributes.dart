import 'package:sentry/sentry.dart';

import '../../sentry_sqflite.dart';

/// Sets the database attributes on the [span].
/// It contains the database system and the database name.
void setDatabaseAttributeData(ISentrySpan? span, String? dbName) {
  span?.setData(SentryDatabase.dbSystemKey, SentryDatabase.dbSystem);
  if (dbName != null) {
    span?.setData(SentryDatabase.dbNameKey, dbName);
  }
}

/// Sets the database attributes on the [span] using InstrumentationSpan.
/// It contains the database system and the database name.
// ignore: invalid_use_of_internal_member
void setDatabaseAttributeDataOnInstrumentationSpan(
  // ignore: invalid_use_of_internal_member
  InstrumentationSpan? span,
  String? dbName,
) {
  span?.setData(SentryDatabase.dbSystemKey, SentryDatabase.dbSystem);
  if (dbName != null) {
    span?.setData(SentryDatabase.dbNameKey, dbName);
  }
}

/// Sets the database attributes on the [breadcrumb].
/// It contains the database system and the database name.
void setDatabaseAttributeOnBreadcrumb(Breadcrumb breadcrumb, String? dbName) {
  breadcrumb.data?[SentryDatabase.dbSystemKey] = SentryDatabase.dbSystem;
  if (dbName != null) {
    breadcrumb.data?[SentryDatabase.dbNameKey] = dbName;
  }
}
