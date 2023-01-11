import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';
import 'dio_event_processor.dart';
import 'failed_request_interceptor.dart';
import 'sentry_transformer.dart';
import 'sentry_dio_client_adapter.dart';

/// Extension to add performance tracing for [Dio]
extension SentryDioExtension on Dio {
  /// Adds support for automatic spans for http requests,
  /// as well as request and response transformations.
  /// This must be the last initialization step of the [Dio] setup, otherwise
  /// your configuration of Dio might overwrite the Sentry configuration.
  void addSentry({
    Hub? hub,
  }) {
    hub = hub ?? HubAdapter();

    // ignore: invalid_use_of_internal_member
    final options = hub.options;

    // Add DioEventProcessor when it's not already present
    if (options.eventProcessors.whereType<DioEventProcessor>().isEmpty) {
      options.sdk.addIntegration('sentry_dio');
      options.addEventProcessor(DioEventProcessor(options));
    }

    if (options.captureFailedRequests) {
      // Add FailedRequestInterceptor at index 0, so it's the first interceptor.
      // This ensures that it is called and not skipped by any previous interceptor.
      interceptors.insert(0, FailedRequestInterceptor());
      // ignore: invalid_use_of_internal_member
      hub.options.sdk.addIntegration('DioHTTPClientError');
    }

    // intercept http requests
    httpClientAdapter = SentryDioClientAdapter(
      client: httpClientAdapter,
      hub: hub,
    );

    // intercept transformations
    transformer = SentryTransformer(
      transformer: transformer,
      hub: hub,
    );
  }
}
