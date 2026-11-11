// ignore_for_file: invalid_use_of_internal_member
import 'package:sentry/sentry.dart';

import '../../sentry_sqflite.dart';

/// Returns the database attributes known when a span is created.
Map<String, dynamic> databaseSpanData(String? dbName) => {
  SemanticAttributesConstants.dbSystemName: SentryDatabase.dbSystemName,
  SemanticAttributesConstants.dbNamespace: ?dbName,
};

/// Sets the database attributes on the [breadcrumb].
/// It contains the database system and the database name.
void setDatabaseAttributeOnBreadcrumb(Breadcrumb breadcrumb, String? dbName) {
  breadcrumb.data?[SemanticAttributesConstants.dbSystemName] =
      SentryDatabase.dbSystemName;
  if (dbName != null) {
    breadcrumb.data?[SemanticAttributesConstants.dbNamespace] = dbName;
  }
}
