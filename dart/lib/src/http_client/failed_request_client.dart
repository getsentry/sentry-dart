import 'package:http/http.dart';
import '../protocol.dart';
import '../hub.dart';
import '../hub_adapter.dart';

/// A [http](https://pub.dev/packages/http)-package compatible HTTP client
/// which records events for failed requests.
///
/// Configured with default values, this captures requests which throw an
/// exception.
/// This can be for example for the following reasons:
/// - In an browser environment this can be requests which fail because of CORS.
/// - In an mobile or desktop application this can be requests which failed
///   because the connection was interrupted.
///
/// Additionally you can configure specific HTTP response codes to be considered
/// as a failed request. In the following example, the status codes 404 and 500
/// are considered a failed request.
///
/// ```dart
/// import 'package:sentry/sentry.dart';
///
/// var client = FailedRequestClient(
///   failedRequestStatusCodes: [404, 500]
/// );
/// ```
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
  FailedRequestClient({
    this.maxRequestBodySize = MaxRequestBodySize.small,
    this.failedRequestStatusCodes = const [],
    Client? client,
    Hub? hub,
  })  : _hub = hub ?? HubAdapter(),
        _client = client ?? Client();

  final Client _client;
  final Hub _hub;

  /// Configures up to which size request bodies should be included in events
  final MaxRequestBodySize maxRequestBodySize;

  /// Describes which HTTP status codes should be considered as a failed
  /// requests.
  ///
  /// Per default no status code is considered a failed request.
  final List<int> failedRequestStatusCodes;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    try {
      final response = await _client.send(request);

      if (failedRequestStatusCodes.contains(response.statusCode)) {
        await _captureException(request: request);
      }

      return response;
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
    Object? exception,
    StackTrace? stackTrace,
    required BaseRequest request,
  }) {
    // As far as I can tell there's no way to get the uri without the query part
    // so we replace it with an empty string.
    final urlWithoutQuery = request.url.replace(query: '').toString();

    final query = request.url.query.isEmpty ? null : request.url.query;

    final sentryRequest = SentryRequest(
      method: request.method,
      headers: request.headers,
      url: urlWithoutQuery,
      queryString: query,
      data: _getDataFromRequest(request),
      other: {
        'Content-Length': request.contentLength.toString(),
      },
    );
    final event = SentryEvent(
      throwable: exception,
      request: sentryRequest,
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

/// Describes the size of http request bodies which should be added to an event
enum MaxRequestBodySize {
  /// Request bodies are never sent
  never,

  /// Only small request bodies will be captured where the cutoff for small
  /// depends on the SDK (typically 4KB)
  small,

  /// Medium and small requests will be captured (typically 10KB)
  medium,

  /// The SDK will always capture the request body for as long as Sentry can
  /// make sense of it
  always,
}
