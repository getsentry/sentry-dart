import 'package:http/http.dart';
import '../hub.dart';
import '../hub_adapter.dart';
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
  SentryHttpClient({Client? client, Hub? hub}) {
    _hub = hub ?? HubAdapter();
    _client = FailedRequestClient(
      hub: _hub,
      client: BreadcrumbClient(
        client: client ?? Client(),
      ),
    );
  }

  late Client _client;
  late Hub _hub;

  @override
  Future<StreamedResponse> send(BaseRequest request) => _client.send(request);

  @override
  void close() => _client.close();
}
