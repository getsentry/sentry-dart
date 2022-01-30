// ignore_for_file: strict_raw_type

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';
import 'tracing_client_adapter.dart';
import 'breadcrumb_client_adapter.dart';

/// A [Dio](https://pub.dev/packages/dio)-package compatible HTTP client adapter.
///
/// It records requests as breadcrumbs. This is on by default.
///
/// It captures requests which throws an exception. This is off by
/// default, set [captureFailedRequests] to `true` to enable it. This can be for
/// example for the following reasons:
/// - In an browser environment this can be requests which fail because of CORS.
/// - In an mobile or desktop application this can be requests which failed
///   because the connection was interrupted.
///
/// Additionally you can configure specific HTTP response codes to be considered
/// as a failed request. This is off by default. Enable it by using it like
/// shown in the following example:
/// The status codes 400 to 404 and 500 are considered a failed request.
///
/// ```dart
/// import 'package:sentry/sentry.dart';
///
/// dio.httpClientAdapter = SentryHttpClientAdapter(
///   failedRequestStatusCodes: [
///     SentryStatusCode.range(400, 404),
///     SentryStatusCode(500),
///   ],
/// );
/// ```
///
/// It starts and finishes a Span if there's a transaction bound to the Scope
/// through the [TracingClientAdapter] client, it's disabled by default.
/// Set [networkTracing] to `true` to enable it.
///
/// Remarks: If this client is used as a wrapper, a call to close also closes
/// the given client.
///
/// Remarks:
/// HTTP traffic can contain PII (personal identifiable information).
/// Read more on data scrubbing [here](https://docs.sentry.io/product/data-management-settings/advanced-datascrubbing/).
class SentryDioClientAdapter extends HttpClientAdapter {
  // ignore: public_member_api_docs
  SentryDioClientAdapter({
    required HttpClientAdapter client,
    Hub? hub,
    bool recordBreadcrumbs = true,
    bool networkTracing = true,
    MaxRequestBodySize maxRequestBodySize = MaxRequestBodySize.never,
    List<SentryStatusCode> failedRequestStatusCodes = const [],
    bool captureFailedRequests = false,
    bool sendDefaultPii = false,
  }) {
    _hub = hub ?? HubAdapter();

    var innerClient = client;

    if (networkTracing) {
      innerClient = TracingClientAdapter(client: innerClient, hub: _hub);
    }

    // The ordering here matters.
    // We don't want to include the breadcrumbs for the current request
    // when capturing it as a failed request.
    // However it still should be added for following events.
    if (recordBreadcrumbs) {
      innerClient = BreadcrumbClientAdapter(client: innerClient, hub: _hub);
    }

    _client = innerClient;
  }

  late HttpClientAdapter _client;
  late Hub _hub;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) =>
      _client.fetch(options, requestStream, cancelFuture);

  @override
  void close({bool force = false}) => _client.close(force: force);
}
