import 'package:meta/meta.dart';

@internal
class SentrySpanOperations {
  static const String uiLoad = 'ui.load';
  static const String uiTimeToInitialDisplay = 'ui.load.initial_display';
  static const String uiTimeToFullDisplay = 'ui.load.full_display';
  static const String dbSqlQuery = 'db.sql.query';
  static const String dbSqlTransaction = 'db.sql.transaction';
  static const String dbSqlBatch = 'db.sql.batch';
  static const String dbOpen = 'db.open';
  static const String dbClose = 'db.close';
}

@internal
class SentrySpanData {
  static const String dbSystemKey = 'db.system';
  static const String dbNameKey = 'db.name';
  static const String dbSchemaKey = 'db.schema';
  static const String dbTableKey = 'db.table';
  static const String dbUrlKey = 'db.url';
  static const String dbSdkKey = 'db.sdk';
  static const String dbQueryKey = 'db.query';
  static const String dbBodyKey = 'db.body';
  static const String dbOperationKey = 'db.operation';
  static const String httpResponseStatusCodeKey = 'http.response.status_code';
  static const String httpResponseContentLengthKey =
      'http.response_content_length';

  static const String dbSystemSqlite = 'db.sqlite';
  static const String dbSystemPostgresql = 'postgresql';
}

@internal
class SentrySpanDescriptions {
  static const String dbTransaction = 'Transaction';
  static String dbBatch({required List<String> statements}) =>
      'Batch $statements';
  static String dbOpen({required String dbName}) => 'Open database $dbName';
  static String dbClose({required String dbName}) => 'Close database $dbName';
}
