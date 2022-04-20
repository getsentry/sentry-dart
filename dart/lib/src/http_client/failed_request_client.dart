import 'package:http/http.dart';
import 'sentry_http_client_error.dart';
import '../protocol.dart';
import '../hub.dart';
import '../hub_adapter.dart';
import '../throwable_mechanism.dart';
import 'sentry_http_client.dart';

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
///   failedRequestStatusCodes: [SentryStatusCode.range(400, 404), SentryStatusCode(500)]
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
    this.maxRequestBodySize = MaxRequestBodySize.never,
    this.failedRequestStatusCodes = const [],
    this.captureFailedRequests = true,
    this.sendDefaultPii = false,
    Client? client,
    Hub? hub,
  })  : _hub = hub ?? HubAdapter(),
        _client = client ?? Client();

  final Client _client;
  final Hub _hub;

  /// Configures wether to record exceptions for failed requests.
  /// Examples for captures exceptions are:
  /// - In an browser environment this can be requests which fail because of CORS.
  /// - In an mobile or desktop application this can be requests which failed
  ///   because the connection was interrupted.
  final bool captureFailedRequests;

  /// Configures up to which size request bodies should be included in events.
  /// This does not change wether an event is captured.
  final MaxRequestBodySize maxRequestBodySize;

  /// Describes which HTTP status codes should be considered as a failed
  /// requests.
  ///
  /// Per default no status code is considered a failed request.
  final List<SentryStatusCode> failedRequestStatusCodes;

  final bool sendDefaultPii;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    int? statusCode;
    Object? exception;
    StackTrace? stackTrace;

    final stopwatch = Stopwatch();
    stopwatch.start();

    try {
      final response = await _client.send(request);
      statusCode = response.statusCode;
      return response;
    } catch (e, st) {
      exception = e;
      stackTrace = st;
      rethrow;
    } finally {
      stopwatch.stop();

      // If captureFailedRequests is true, there statusCode is null.
      // So just one of these blocks can be called.

      if (captureFailedRequests && exception != null) {
        await _captureEvent(
          exception: exception,
          stackTrace: stackTrace,
          request: request,
          requestDuration: stopwatch.elapsed,
        );
      } else if (failedRequestStatusCodes.containsStatusCode(statusCode)) {
        final message =
            'Event was captured because the request status code was $statusCode';
        final httpException = SentryHttpClientError(message);

        // Capture an exception if the status code is considered bad
        await _captureEvent(
          exception: exception ?? httpException,
          request: request,
          reason: message,
          requestDuration: stopwatch.elapsed,
        );
      }
    }
  }

  @override
  void close() => _client.close();

  // See https://develop.sentry.dev/sdk/event-payloads/request/
  Future<void> _captureEvent({
    required Object? exception,
    StackTrace? stackTrace,
    String? reason,
    required Duration requestDuration,
    required BaseRequest request,
  }) async {
    // As far as I can tell there's no way to get the uri without the query part
    // so we replace it with an empty string.
    final urlWithoutQuery = request.url.replace(query: '').toString();

    final query = request.url.query.isEmpty ? null : request.url.query;

    final sentryRequest = SentryRequest(
      method: request.method,
      headers: sendDefaultPii ? request.headers : null,
      url: urlWithoutQuery,
      queryString: query,
      cookies: sendDefaultPii ? request.headers['Cookie'] : null,
      data: _getDataFromRequest(request),
      other: {
        'content_length': request.contentLength.toString(),
        'duration': requestDuration.toString(),
      },
    );

    final mechanism = Mechanism(
      type: 'SentryHttpClient',
      description: reason,
    );
    final throwableMechanism = ThrowableMechanism(mechanism, exception);

    final event = SentryEvent(
      throwable: throwableMechanism,
      request: sentryRequest,
    );
    await _hub.captureEvent(event, stackTrace: stackTrace);
  }

  // Types of Request can be found here:
  // https://pub.dev/documentation/http/latest/http/http-library.html
  Object? _getDataFromRequest(BaseRequest request) {
    final contentLength = request.contentLength;
    if (contentLength == null) {
      return null;
    }
    if (!maxRequestBodySize.shouldAddBody(contentLength)) {
      return null;
    }
    if (request is MultipartRequest) {
      final data = <String, String>{...request.fields};
      return data;
    }

    if (request is Request) {
      return request.body;
    }

    // There's nothing we can do for a StreamedRequest
    return null;
  }
}

extension _ListX on List<SentryStatusCode> {
  bool containsStatusCode(int? statusCode) {
    if (statusCode == null) {
      return false;
    }
    return any((element) => element.isInRange(statusCode));
  }
}
