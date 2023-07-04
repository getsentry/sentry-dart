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
  static const autoFileSqfliteOpenDatabase = 'auto.file.sqflite.open_database';
  static const autoFileSqfliteBatch = 'auto.file.sqflite.batch';
  static const autoFileSqfliteDatabase = 'auto.file.sqflite.database';
  static const autoFileSqfliteDatabaseExecutor =
      'auto.file.sqflite.database_executor';
  static const autoFileSqfliteDatabaseFactory =
      'auto.file.sqflite.database_factory';
}
