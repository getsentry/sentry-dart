import 'package:meta/meta.dart';

@internal
class SentryTraceOrigins {
  static const manual = 'manual';

  static const autoNavigationSentryNavigatorObserver = 'auto.navigation.sentry_navigator_observer';
  static const autoHttpHttpTracingClient = 'auto.http.http.tracing_client';
  static const autoHttpDioTracingClientAdapter = 'auto.http.dio.tracing_client_adapter';
}
