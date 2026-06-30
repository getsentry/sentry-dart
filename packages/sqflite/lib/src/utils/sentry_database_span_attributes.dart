// ignore_for_file: invalid_use_of_internal_member
import 'package:sentry/sentry.dart';

import '../../sentry_sqflite.dart';

/// Sets the database attributes on the [span] using InstrumentationSpan.
/// It contains the database system and the database name.
void setDatabaseAttributeData(
  InstrumentationSpan? span,
  String? dbName,
) {
  span?.setData(
    SemanticAttributesConstants.dbSystemName,
    SentryDatabase.dbSystem,
  );
  if (dbName != null) {
    span?.setData(SemanticAttributesConstants.dbNamespace, dbName);
  }
}

/// Sets the database attributes on the [breadcrumb].
/// It contains the database system and the database name.
void setDatabaseAttributeOnBreadcrumb(Breadcrumb breadcrumb, String? dbName) {
  breadcrumb.data?[SemanticAttributesConstants.dbSystemName] =
      SentryDatabase.dbSystem;
  if (dbName != null) {
    breadcrumb.data?[SemanticAttributesConstants.dbNamespace] = dbName;
  }
}
