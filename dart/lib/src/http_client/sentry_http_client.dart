import 'package:http/http.dart';
import 'tracing_client.dart';
import '../hub.dart';
import '../hub_adapter.dart';
import '../protocol.dart';
import 'breadcrumb_client.dart';
import 'failed_request_client.dart';

/// A [http](https://pub.dev/packages/http)-package compatible HTTP client.
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
/// var client = SentryHttpClient(
///   failedRequestStatusCodes: [
///     SentryStatusCode.range(400, 404),
///     SentryStatusCode(500),
///   ],
/// );
/// ```
///
/// It starts and finishes a Span if there's a transaction bound to the Scope
/// through the [TracingClient] client, it's disabled by default.
/// Set [networkTracing] to `true` to enable it.
///
/// Remarks: If this client is used as a wrapper, a call to close also closes
/// the given client.
///
/// The `SentryHttpClient` can be used as a standalone client like this:
/// ```dart
/// import 'package:sentry/sentry.dart';
///
/// var client = SentryHttpClient();
/// try {
///  var uriResponse = await client.post('https://example.com/whatsit/create',
///      body: {'name': 'doodle', 'color': 'blue'});
///  print(await client.get(uriResponse.bodyFields['uri']));
/// } finally {
///  client.close();
/// }
/// ```
///
/// The `SentryHttpClient` can also be used as a wrapper for your own HTTP
/// [Client](https://pub.dev/documentation/http/latest/http/Client-class.html):
/// ```dart
/// import 'package:sentry/sentry.dart';
/// import 'package:http/http.dart' as http;
///
/// final myClient = http.Client();
///
/// var client = SentryHttpClient(client: myClient);
/// try {
///  var uriResponse = await client.post('https://example.com/whatsit/create',
///      body: {'name': 'doodle', 'color': 'blue'});
///  print(await client.get(uriResponse.bodyFields['uri']));
/// } finally {
///  client.close();
/// }
///
/// Remarks:
/// HTTP traffic can contain PII (personal identifiable information).
/// Read more on data scrubbing [here](https://docs.sentry.io/product/data-management-settings/advanced-datascrubbing/).
/// ```
class SentryHttpClient extends BaseClient {
  SentryHttpClient({
    Client? client,
    Hub? hub,
    bool recordBreadcrumbs = true,
    MaxRequestBodySize maxRequestBodySize = MaxRequestBodySize.never,
    List<SentryStatusCode> failedRequestStatusCodes = const [],
    bool captureFailedRequests = false,
    bool sendDefaultPii = false,
    bool networkTracing = false,
  }) {
    _hub = hub ?? HubAdapter();

    var innerClient = client ?? Client();

    innerClient = FailedRequestClient(
      failedRequestStatusCodes: failedRequestStatusCodes,
      captureFailedRequests: captureFailedRequests,
      maxRequestBodySize: maxRequestBodySize,
      sendDefaultPii: sendDefaultPii,
      hub: _hub,
      client: innerClient,
    );

    if (networkTracing) {
      innerClient = TracingClient(client: innerClient, hub: _hub);
    }

    // The ordering here matters.
    // We don't want to include the breadcrumbs for the current request
    // when capturing it as a failed request.
    // However it still should be added for following events.
    if (recordBreadcrumbs) {
      innerClient = BreadcrumbClient(client: innerClient, hub: _hub);
    }

    _client = innerClient;
  }

  late Client _client;
  late Hub _hub;

  @override
  Future<StreamedResponse> send(BaseRequest request) => _client.send(request);

  // See https://github.com/getsentry/sentry-dart/pull/226#discussion_r536984785
  @override
  void close() => _client.close();
}

class SentryStatusCode {
  SentryStatusCode.range(this._min, this._max)
      : assert(_min <= _max),
        assert(_min > 0 && _max > 0);

  SentryStatusCode(int statusCode)
      : _min = statusCode,
        _max = statusCode,
        assert(statusCode > 0);

  final int _min;
  final int _max;

  bool isInRange(int statusCode) => statusCode >= _min && statusCode <= _max;

  @override
  String toString() {
    if (_min == _max) {
      return _min.toString();
    }
    return '$_min..$_max';
  }
}
