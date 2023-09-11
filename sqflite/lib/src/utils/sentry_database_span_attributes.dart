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
