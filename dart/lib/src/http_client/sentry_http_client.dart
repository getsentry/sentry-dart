import 'package:http/http.dart';

import '../../sentry.dart';

/// A [http](https://pub.dev/packages/http)-package compatible HTTP client
/// which records requests as breadcrumbs.
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
//
// Possible enhancement:
// Track the time the HTTP request took.
// For example with Darts Stopwatch:
// https://api.dart.dev/stable/2.10.4/dart-core/Stopwatch-class.html
class SentryHttpClient extends BaseClient {
  SentryHttpClient({Client client, Hub hub}) {
    _hub = hub ?? HubAdapter();
    _client = client ?? Client();
  }

  Client _client;
  Hub _hub;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final response = await _client.send(request);
    // See https://develop.sentry.dev/sdk/event-payloads/breadcrumbs/
    // for how the breadcrumb should look like
    _hub.addBreadcrumb(
      Breadcrumb(
        type: 'http',
        category: 'http',
        data: {
          'url': request.url.toString(),
          'method': request.method,
          'status_code': response.statusCode,
          // reason is optional, therefor only add it in case it is not null
          if (response.reasonPhrase != null) 'reason': response.reasonPhrase,
        },
      ),
    );
    return response;
  }

  @override
  void close() {
    // See https://github.com/getsentry/sentry-dart/pull/226#discussion_r536984785
    _client.close();
  }
}
