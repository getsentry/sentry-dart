import 'package:http/http.dart';
import 'tracing_client.dart';
import '../hub.dart';
import '../hub_adapter.dart';
import 'breadcrumb_client.dart';
import 'failed_request_client.dart';

/// A [http](https://pub.dev/packages/http)-package compatible HTTP client.
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
/// If empty request status codes are provided, all failure requests will be
/// captured. Per default, codes in the range 500-599 are recorded.
///
/// If you provide failed request targets, the SDK will only capture HTTP
/// Client errors if the HTTP Request URL is a match for any of the provided
/// targets.
///
/// ```dart
/// var client = SentryHttpClient(
///   failedRequestTargets: ['my-api.com'],
/// );
/// ```
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
///
/// The constructor parameter `captureFailedRequests` will override what you
/// have configured in options.
/// ```
class SentryHttpClient extends BaseClient {
  static const defaultFailedRequestStatusCodes = [
    SentryStatusCode.defaultRange()
  ];
  static const defaultFailedRequestTargets = ['.*'];

  SentryHttpClient({
    Client? client,
    Hub? hub,
    List<SentryStatusCode> failedRequestStatusCodes =
        defaultFailedRequestStatusCodes,
    List<String> failedRequestTargets = defaultFailedRequestTargets,
    bool? captureFailedRequests,
  }) {
    _hub = hub ?? HubAdapter();

    var innerClient = client ?? Client();

    innerClient = FailedRequestClient(
      failedRequestStatusCodes: failedRequestStatusCodes,
      failedRequestTargets: failedRequestTargets,
      hub: _hub,
      client: innerClient,
      captureFailedRequests: captureFailedRequests,
    );

    if (_hub.options.isTracingEnabled()) {
      innerClient = TracingClient(client: innerClient, hub: _hub);
      _hub.options.sdk.addIntegration('HTTPNetworkTracing');
    }

    // The ordering here matters.
    // We don't want to include the breadcrumbs for the current request
    // when capturing it as a failed request.
    // However it still should be added for following events.
    if (_hub.options.recordHttpBreadcrumbs) {
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
  static const _defaultMin = 500;
  static const _defaultMax = 599;

  const SentryStatusCode.defaultRange()
      : _min = _defaultMin,
        _max = _defaultMax;

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
