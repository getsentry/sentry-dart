import 'package:http/http.dart';
import '../protocol.dart';
import '../hub.dart';
import '../hub_adapter.dart';
import '../utils/url_details.dart';
import '../utils/url_utils.dart';

/// A [http](https://pub.dev/packages/http)-package compatible HTTP client
/// which records requests as breadcrumbs.
///
/// Remarks:
/// If this client is used as a wrapper, a call to close also closes the
/// given client.
///
/// The `BreadcrumbClient` can be used as a standalone client like this:
/// ```dart
/// import 'package:sentry/sentry.dart';
///
/// var client = BreadcrumbClient();
/// try {
///  var uriResponse = await client.post('https://example.com/whatsit/create',
///      body: {'name': 'doodle', 'color': 'blue'});
///  print(await client.get(uriResponse.bodyFields['uri']));
/// } finally {
///  client.close();
/// }
/// ```
///
/// The `BreadcrumbClient` can also be used as a wrapper for your own
/// HTTP [Client](https://pub.dev/documentation/http/latest/http/Client-class.html):
/// ```dart
/// import 'package:sentry/sentry.dart';
/// import 'package:http/http.dart' as http;
///
/// final myClient = http.Client();
///
/// var client = BreadcrumbClient(client: myClient);
/// try {
///  var uriResponse = await client.post('https://example.com/whatsit/create',
///      body: {'name': 'doodle', 'color': 'blue'});
///  print(await client.get(uriResponse.bodyFields['uri']));
/// } finally {
///  client.close();
/// }
/// ```
class BreadcrumbClient extends BaseClient {
  BreadcrumbClient({Client? client, Hub? hub})
      : _hub = hub ?? HubAdapter(),
        _client = client ?? Client();

  final Client _client;
  final Hub _hub;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    // See https://develop.sentry.dev/sdk/event-payloads/breadcrumbs/

    var requestHadException = false;
    int? statusCode;
    String? reason;
    int? responseBodySize;

    final stopwatch = Stopwatch();
    stopwatch.start();

    try {
      final response = await _client.send(request);

      statusCode = response.statusCode;
      reason = response.reasonPhrase;
      responseBodySize = response.contentLength;

      return response;
    } catch (_) {
      requestHadException = true;
      rethrow;
    } finally {
      stopwatch.stop();

      final urlDetails = UrlUtils.parse(request.url.toString()) ?? UrlDetails();

      var breadcrumb = Breadcrumb.http(
        level: requestHadException ? SentryLevel.error : SentryLevel.info,
        url: Uri.parse(urlDetails.urlOrFallback),
        method: request.method,
        statusCode: statusCode,
        reason: reason,
        requestDuration: stopwatch.elapsed,
        requestBodySize: request.contentLength,
        responseBodySize: responseBodySize,
        httpQuery: urlDetails.query,
        httpFragment: urlDetails.fragment,
      );

      await _hub.addBreadcrumb(breadcrumb);
    }
  }

  @override
  void close() => _client.close();
}
