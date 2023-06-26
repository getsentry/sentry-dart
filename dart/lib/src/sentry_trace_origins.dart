import 'package:meta/meta.dart';

@internal
class SentryTraceOrigins {
  static const manual = 'manual';

  static const autoNavigationSentryNavigatorObserver =
      'auto.navigation.sentry_navigator_observer';
  static const autoHttpHttpTracingClient = 'auto.http.http.tracing_client';
  static const autoHttpDioTracingClientAdapter =
      'auto.http.dio.tracing_client_adapter';
  static const autoHttpDioSentryTransformer =
      'auto.http.dio.sentry_transformer';
  static const autoFile = 'auto.file';
  static const autoFileAssetBundle = 'auto.file.asset_bundle';
  static const autoFileSqflite = 'auto.file.sqflite';
  static const autoFileSqfliteSentryBatch = 'auto.file.sqflite.sentry_batch';
  static const autoFileSqfliteSentryDatabase =
      'auto.file.sqflite.sentry_database';
  static const autoFileSqfliteSentryDatabaseExecutor =
      'auto.file.sqflite.sentry_database_executor';
  static const autoFileSqfliteSentrySqfliteDatabaseFactory =
      'auto.file.sqflite.sentry_sqflite_database_factory';
}
