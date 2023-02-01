import 'package:diox/diox.dart';
import 'package:sentry/sentry.dart';
import 'diox_event_processor.dart';
import 'failed_request_interceptor.dart';
import 'sentry_transformer.dart';
import 'sentry_diox_client_adapter.dart';

/// Extension to add performance tracing for [Dio]
extension SentryDioxExtension on Dio {
  /// Adds support for automatic spans for http requests,
  /// as well as request and response transformations.
  /// This must be the last initialization step of the [Dio] setup, otherwise
  /// your configuration of Dio might overwrite the Sentry configuration.
  void addSentry({
    bool recordBreadcrumbs = true,
    bool networkTracing = true,
    MaxRequestBodySize maxRequestBodySize = MaxRequestBodySize.never,
    MaxResponseBodySize maxResponseBodySize = MaxResponseBodySize.never,
    bool captureFailedRequests = false,
    Hub? hub,
  }) {
    hub = hub ?? HubAdapter();

    // ignore: invalid_use_of_internal_member
    final options = hub.options;

    // Add DioEventProcessor when it's not already present
    if (options.eventProcessors.whereType<DioxEventProcessor>().isEmpty) {
      options.sdk.addIntegration('sentry_diox');
      options.addEventProcessor(
        DioxEventProcessor(
          options,
          maxRequestBodySize,
          maxResponseBodySize,
        ),
      );
    }

    if (captureFailedRequests) {
      // Add FailedRequestInterceptor at index 0, so it's the first interceptor.
      // This ensures that it is called and not skipped by any previous interceptor.
      interceptors.insert(0, FailedRequestInterceptor());
      // ignore: invalid_use_of_internal_member
      hub.options.sdk.addIntegration('DioxHTTPClientError');
    }

    // intercept http requests
    httpClientAdapter = SentryDioxClientAdapter(
      client: httpClientAdapter,
      recordBreadcrumbs: recordBreadcrumbs,
      networkTracing: networkTracing,
      hub: hub,
    );

    // intercept transformations
    transformer = SentryTransformer(
      transformer: transformer,
      hub: hub,
    );
  }
}
