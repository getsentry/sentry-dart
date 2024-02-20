import 'package:meta/meta.dart';

@internal
class SentryTraceOrigins {
  static const manual = 'manual';

  static const autoNavigationRouteObserver = 'auto.navigation.route_observer';
  static const autoHttpHttp = 'auto.http.http';
  static const autoHttpDioHttpClientAdapter =
      'auto.http.dio.http_client_adapter';
  static const autoHttpDioTransformer = 'auto.http.dio.transformer';
  static const autoFile = 'auto.file';
  static const autoFileAssetBundle = 'auto.file.asset_bundle';
  static const autoDbSqfliteOpenDatabase = 'auto.db.sqflite.open_database';
  static const autoDbSqfliteBatch = 'auto.db.sqflite.batch';
  static const autoDbSqfliteDatabase = 'auto.db.sqflite.database';
  static const autoDbSqfliteDatabaseExecutor =
      'auto.db.sqflite.database_executor';
  static const autoDbSqfliteDatabaseFactory =
      'auto.db.sqflite.database_factory';
  static const autoDbIsar = 'auto.db.isar';
  static const autoDbIsarCollection = 'auto.db.isar.collection';
  static const autoDbHive = 'auto.db.hive';
  static const autoDbHiveBoxBase = 'auto.db.hive.box_base';
  static const autoDbHiveLazyBox = 'auto.db.hive.lazy_box';
  static const autoDbHiveBoxCollection = 'auto.db.hive.box_collection';
  static const autoDbDriftQueryExecutor = 'auto.db.drift.query.executor';
  static const autoDbDriftTransactionExecutor =
      'auto.db.drift.transaction.executor';
  static const autoUiTimeToDisplay = 'auto.ui.time_to_display';
  static const manualUiTimeToDisplay = 'manual.ui.time_to_display';
}
