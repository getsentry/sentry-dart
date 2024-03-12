// ignore_for_file: deprecated_member_use

import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';
import 'dio_error_extractor.dart';
import 'dio_event_processor.dart';
import 'dio_stacktrace_extractor.dart';
import 'failed_request_interceptor.dart';
import 'sentry_transformer.dart';
import 'sentry_dio_client_adapter.dart';
import 'version.dart';

/// Extension to add performance tracing for [Dio]
extension SentryDioExtension on Dio {
  /// Adds support for automatic spans for http requests,
  /// as well as request and response transformations.
  /// This must be the last initialization step of the [Dio] setup, otherwise
  /// your configuration of Dio might overwrite the Sentry configuration.
  ///
  /// You can also configure specific HTTP response codes to be considered
  /// as a failed request. In the following example, the status codes 404 and 500
  /// are considered a failed request.
  ///
  /// ```dart
  /// dio.addSentry(
  ///   failedRequestStatusCodes: [
  ///     SentryStatusCode.range(400, 404),
  ///     SentryStatusCode(500),
  ///   ]
  /// );
  /// ```
  ///
  /// If empty request status codes are provided, all failure requests will be
  /// captured. Per default, codes in the range 500-599 are recorded.
  ///
  /// If you provide failed request targets, the SDK will only capture HTTP
  /// Client errors if the HTTP Request URL is a match for any of the provided
  /// targets.
  ///
  /// ```dart
  /// dio.addSentry(
  ///   failedRequestTargets: ['my-api.com'],
  /// );
  /// ```
  ///
  /// The captureFailedRequests argument will take precedent over options.
  void addSentry({
    Hub? hub,
    List<SentryStatusCode> failedRequestStatusCodes =
        SentryHttpClient.defaultFailedRequestStatusCodes,
    List<String> failedRequestTargets =
        SentryHttpClient.defaultFailedRequestTargets,
    bool? captureFailedRequests,
  }) {
    hub = hub ?? HubAdapter();

    // ignore: invalid_use_of_internal_member
    final options = hub.options;

    // Add to get inner exception
    if (options.exceptionCauseExtractor(DioError) == null) {
      options.addExceptionCauseExtractor(DioErrorExtractor());
    }

    // Add to get inner stacktrace
    if (options.exceptionStackTraceExtractor(DioError) == null) {
      options.addExceptionStackTraceExtractor(DioStackTraceExtractor());
    }

    // Add DioEventProcessor when it's not already present
    if (options.eventProcessors.whereType<DioEventProcessor>().isEmpty) {
      options.sdk.addIntegration('sentry_dio');
      options.addEventProcessor(DioEventProcessor(options));
    }
    options.sdk.addPackage(packageName, sdkVersion);

    if (captureFailedRequests ?? options.captureFailedRequests) {
      // Add FailedRequestInterceptor at index 0, so it's the first interceptor.
      // This ensures that it is called and not skipped by any previous interceptor.
      interceptors.insert(
        0,
        FailedRequestInterceptor(
          failedRequestStatusCodes: failedRequestStatusCodes,
          failedRequestTargets: failedRequestTargets,
        ),
      );
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
