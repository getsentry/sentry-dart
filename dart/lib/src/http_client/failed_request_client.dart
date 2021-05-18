import 'package:http/http.dart';
import '../protocol.dart';
import '../hub.dart';
import '../hub_adapter.dart';

/// A [http](https://pub.dev/packages/http)-package compatible HTTP client
/// which records sends events for failed requests.
///
/// Remarks:
/// If this client is used as a wrapper, a call to close also closes the
/// given client.
///
/// The `FailedRequestClient` can be used as a standalone client like this:
/// ```dart
/// import 'package:sentry/sentry.dart';
///
/// var client = FailedRequestClient();
/// try {
///  var uriResponse = await client.post('https://example.com/whatsit/create',
///      body: {'name': 'doodle', 'color': 'blue'});
///  print(await client.get(uriResponse.bodyFields['uri']));
/// } finally {
///  client.close();
/// }
/// ```
///
/// The `FailedRequestClient` can also be used as a wrapper for your own
/// HTTP [Client](https://pub.dev/documentation/http/latest/http/Client-class.html):
/// ```dart
/// import 'package:sentry/sentry.dart';
/// import 'package:http/http.dart' as http;
///
/// final myClient = http.Client();
///
/// var client = FailedRequestClient(client: myClient);
/// try {
///  var uriResponse = await client.post('https://example.com/whatsit/create',
///      body: {'name': 'doodle', 'color': 'blue'});
///  print(await client.get(uriResponse.bodyFields['uri']));
/// } finally {
///  client.close();
/// }
/// ```
class FailedRequestClient extends BaseClient {
  FailedRequestClient({Client? client, Hub? hub})
      : _hub = hub ?? HubAdapter(),
        _client = client ?? Client();

  final Client _client;
  final Hub _hub;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    try {
      return await _client.send(request);
    } catch (exception, stackTrace) {
      await _captureException(
        exception: exception,
        stackTrace: stackTrace,
        request: request,
      );

      rethrow;
    }
  }

  @override
  void close() {
    // See https://github.com/getsentry/sentry-dart/pull/226#discussion_r536984785
    _client.close();
  }

  // See https://develop.sentry.dev/sdk/event-payloads/request/
  Future<void> _captureException({
    required Object exception,
    required StackTrace stackTrace,
    required BaseRequest request,
  }) {
    final sentryRequest = SentryRequest(
      method: request.method,
      headers: request.headers,
      url: request.url.toString(),
      data: _getDataFromRequest(request),
      other: {
        'Content-Length': request.contentLength.toString(),
      },
    );
    final event = SentryEvent(
      throwable: exception,
      request: sentryRequest,
      culprit: 'SentryHttpClient',
      level: SentryLevel.error,
    );
    return _hub.captureEvent(event, stackTrace: stackTrace);
  }

  // Types of Request can be found here:
  // https://pub.dev/documentation/http/latest/http/http-library.html
  Object? _getDataFromRequest(BaseRequest request) {
    if (request is MultipartRequest) {
      final data = <String, String>{...request.fields};
      // TODO request.files
      return data;
    }

    if (request is Request) {
      return request.body;
    }

    // There's nothing we can do for a StreamedRequest
    return null;
  }
}
