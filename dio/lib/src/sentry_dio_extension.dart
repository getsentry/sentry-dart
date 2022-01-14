import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';
import 'sentry_transformer.dart';
import 'sentry_dio_client_adapter.dart';

/// Extension to add performance tracing for [Dio]
extension SentryDioExtension on Dio {
  /// Adds support for automatic spans for http requests,
  /// as well as request and response transformations.
  /// This must be the last initialization step of the [Dio] setup, otherwise
  /// your configuration of Dio might overwrite the Sentry configuration.
  void addSentry({
    bool recordBreadcrumbs = true,
    bool networkTracing = true,
    MaxRequestBodySize maxRequestBodySize = MaxRequestBodySize.never,
    List<SentryStatusCode> failedRequestStatusCodes = const [],
    bool captureFailedRequests = false,
    bool sendDefaultPii = false,
  }) {
    // intercept http requests
    httpClientAdapter = SentryDioClientAdapter(
      client: httpClientAdapter,
      recordBreadcrumbs: recordBreadcrumbs,
      networkTracing: networkTracing,
      maxRequestBodySize: maxRequestBodySize,
      failedRequestStatusCodes: failedRequestStatusCodes,
      captureFailedRequests: captureFailedRequests,
      sendDefaultPii: sendDefaultPii,
    );

    // intercept transformations
    transformer = SentryTransformer(transformer: transformer);
  }
}
