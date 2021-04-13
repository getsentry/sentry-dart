import 'package:http/http.dart';
import '../protocol/sentry_level.dart';
import '../protocol/breadcrumb.dart';
import '../hub.dart';
import '../hub_adapter.dart';

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
class SentryHttpClient extends BaseClient {
  SentryHttpClient({Client? client, Hub? hub})
      : _hub = hub ?? HubAdapter(),
        _client = client ?? Client();

  final Client _client;
  final Hub _hub;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    // See https://develop.sentry.dev/sdk/event-payloads/breadcrumbs/
    var breadcrumb = Breadcrumb(
      type: 'http',
      category: 'http',
      data: {
        'url': request.url.toString(),
        'method': request.method,
      },
    );

    final stopwatch = Stopwatch();
    stopwatch.start();

    try {
      final response = await _client.send(request);

      breadcrumb.data?.addAll({
        'status_code': response.statusCode,
        if (response.reasonPhrase != null) 'reason': response.reasonPhrase,
      });

      return response;
    } finally {
      stopwatch.stop();
      breadcrumb.data?['duration'] = stopwatch.elapsed.toString();

      // If breadcrum.data does not contain a response status code
      // it was an erroneous request. Set breadcrumb level to error
      if (!(breadcrumb.data?.containsKey('status_code') ?? false)) {
        breadcrumb = breadcrumb.copyWith(level: SentryLevel.error);
      }

      _hub.addBreadcrumb(breadcrumb);
    }
  }

  @override
  void close() {
    // See https://github.com/getsentry/sentry-dart/pull/226#discussion_r536984785
    _client.close();
  }
}
