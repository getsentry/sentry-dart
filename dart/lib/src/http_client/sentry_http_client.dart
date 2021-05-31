import 'package:http/http.dart';
import '../hub.dart';
import '../hub_adapter.dart';
import '../protocol.dart';
import 'breadcrumb_client.dart';
import 'failed_request_client.dart';

/// A [http](https://pub.dev/packages/http)-package compatible HTTP client
/// which combines the functionality of [FailedRequestClient] and
/// [BreadcrumbClient].
///
/// Remarks:
/// If this client is used as a wrapper, a call to close also closes the
/// given client.
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
/// The `SentryHttpClient` can also be used as a wrapper for your own
/// HTTP [Client](https://pub.dev/documentation/http/latest/http/Client-class.html):
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
/// ```
class SentryHttpClient extends BaseClient {
  SentryHttpClient({
    Client? client,
    Hub? hub,
    bool recordBreadcrumbs = true,
    MaxRequestBodySize maxRequestBodySize = MaxRequestBodySize.never,
    List<SentryStatusCode> failedRequestStatusCodes = const [],
    bool captureFailedRequests = false,
  }) {
    _hub = hub ?? HubAdapter();

    final innerClient = client ?? Client();

    _client = FailedRequestClient(
      failedRequestStatusCodes: failedRequestStatusCodes,
      captureFailedRequests: captureFailedRequests,
      maxRequestBodySize: maxRequestBodySize,
      hub: _hub,
      client: recordBreadcrumbs
          ? BreadcrumbClient(client: innerClient)
          : innerClient,
    );
  }

  late Client _client;
  late Hub _hub;

  @override
  Future<StreamedResponse> send(BaseRequest request) => _client.send(request);

  @override
  void close() => _client.close();
}

class SentryStatusCode {
  SentryStatusCode.range(this._lower, this._upper)
      : assert(_lower <= _upper),
        assert(_lower > 0 && _upper > 0);

  SentryStatusCode(int statusCode)
      : _lower = statusCode,
        _upper = statusCode,
        assert(statusCode > 0);

  final int _lower;
  final int _upper;

  bool isInRange(int statusCode) =>
      statusCode >= _lower && statusCode <= _upper;

  @override
  String toString() {
    if (_lower == _upper) {
      return _lower.toString();
    }
    return '$_lower..$_upper';
  }
}
