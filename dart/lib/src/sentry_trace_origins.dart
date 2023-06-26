import 'package:meta/meta.dart';

@internal
class SentryTraceOrigins {
  static const manual = 'manual';

  static const autoNavigationSentryNavigatorObserver = 'auto.navigation.sentry_navigator_observer';
  static const autoHttpHttpTracingClient = 'auto.http.http.tracing_client';
  static const autoHttpDioTracingClientAdapter = 'auto.http.dio.tracing_client_adapter';
  static const autoHttpDioSentryTransformer = 'auto.http.dio.sentry_transformer';
  static const autoFile = 'auto.file';
  static const autoFileAssetBundle = 'auto.file.asset_bundle';
}
