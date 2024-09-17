import 'package:http/http.dart';
import '../hint.dart';
import '../type_check_hint.dart';
import '../utils/http_deep_copy_streamed_response.dart';
import '../utils/tracing_utils.dart';
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
    this.failedRequestStatusCodes =
        SentryHttpClient.defaultFailedRequestStatusCodes,
    this.failedRequestTargets = SentryHttpClient.defaultFailedRequestTargets,
    Client? client,
    Hub? hub,
    bool? captureFailedRequests,
  })  : _hub = hub ?? HubAdapter(),
        _client = client ?? Client(),
        _captureFailedRequests = captureFailedRequests {
    if (captureFailedRequests ?? _hub.options.captureFailedRequests) {
      _hub.options.sdk.addIntegration('HTTPClientError');
    }
  }

  final Client _client;
  final Hub _hub;
  final bool? _captureFailedRequests;

  /// Describes which HTTP status codes should be considered as a failed
  /// requests.
  ///
  /// Per default no status code is considered a failed request.
  final List<SentryStatusCode> failedRequestStatusCodes;

  final List<String> failedRequestTargets;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    int? statusCode;
    Object? exception;
    StackTrace? stackTrace;
    StreamedResponse? response;
    List<StreamedResponse> copiedResponses = [];

    final stopwatch = Stopwatch();
    stopwatch.start();

    try {
      response = await _client.send(request);
      copiedResponses = await deepCopyStreamedResponse(response, 2);
      statusCode = copiedResponses[0].statusCode;
      return copiedResponses[0];
    } catch (e, st) {
      exception = e;
      stackTrace = st;
      rethrow;
    } finally {
      stopwatch.stop();

      await captureEvent(
        _hub,
        exception: exception,
        stackTrace: stackTrace,
        request: request,
        requestDuration: stopwatch.elapsed,
        response: copiedResponses.isNotEmpty ? copiedResponses[1] : null,
        reason: 'HTTP Client Event with status code: $statusCode',
      );
    }
  }

  @override
  void close() => _client.close();
}

extension _ListX on List<SentryStatusCode> {
  bool _containsStatusCode(int? statusCode) {
    if (statusCode == null) {
      return false;
    }
    return any((element) => element.isInRange(statusCode));
  }
}
