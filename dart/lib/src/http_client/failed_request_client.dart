import 'package:http/http.dart';
import '../hint.dart';
import '../type_check_hint.dart';
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

    final stopwatch = Stopwatch();
    stopwatch.start();

    try {
      response = await _client.send(request);
      statusCode = response.statusCode;
      return response;
    } catch (e, st) {
      exception = e;
      stackTrace = st;
      rethrow;
    } finally {
      stopwatch.stop();
      await _captureEventIfNeeded(
        request,
        statusCode,
        exception,
        stackTrace,
        response,
        stopwatch.elapsed,
      );
    }
  }

  Future<void> _captureEventIfNeeded(
      BaseRequest request,
      int? statusCode,
      Object? exception,
      StackTrace? stackTrace,
      StreamedResponse? response,
      Duration duration) async {
    if (!(_captureFailedRequests ?? _hub.options.captureFailedRequests)) {
      return;
    }

    // Only check `failedRequestStatusCodes` & `failedRequestTargets` if no exception was thrown.
    if (exception == null) {
      if (!failedRequestStatusCodes._containsStatusCode(statusCode)) {
        return;
      }
      if (!containsTargetOrMatchesRegExp(
          failedRequestTargets, request.url.toString())) {
        return;
      }
    }

    final reason = 'HTTP Client Error with status code: $statusCode';
    exception ??= SentryHttpClientError(reason);

    await _captureEvent(
      exception: exception,
      stackTrace: stackTrace,
      request: request,
      requestDuration: duration,
      response: response,
      reason: reason,
    );
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
    required StreamedResponse? response,
  }) async {
    final sentryRequest = SentryRequest.fromUri(
      method: request.method,
      headers: _hub.options.sendDefaultPii ? request.headers : null,
      uri: request.url,
      data: _hub.options.sendDefaultPii ? _getDataFromRequest(request) : null,
      // ignore: deprecated_member_use_from_same_package
      other: {
        'content_length': request.contentLength.toString(),
        'duration': requestDuration.toString(),
      },
    );

    final mechanism = Mechanism(
      type: 'SentryHttpClient',
      description: reason,
    );

    bool? snapshot;
    if (exception is SentryHttpClientError) {
      snapshot = true;
    }

    final throwableMechanism = ThrowableMechanism(
      mechanism,
      exception,
      snapshot: snapshot,
    );

    final event = SentryEvent(
      throwable: throwableMechanism,
      request: sentryRequest,
      timestamp: _hub.options.clock(),
    );

    final hint = Hint.withMap({TypeCheckHint.httpRequest: request});

    if (response != null) {
      event.contexts.response = SentryResponse(
        headers: _hub.options.sendDefaultPii ? response.headers : null,
        bodySize: response.contentLength,
        statusCode: response.statusCode,
      );
      hint.set(TypeCheckHint.httpResponse, response);
    }

    await _hub.captureEvent(
      event,
      stackTrace: stackTrace,
      hint: hint,
    );
  }

  // Types of Request can be found here:
  // https://pub.dev/documentation/http/latest/http/http-library.html
  Object? _getDataFromRequest(BaseRequest request) {
    final contentLength = request.contentLength;
    if (contentLength == null) {
      return null;
    }
    if (!_hub.options.maxRequestBodySize.shouldAddBody(contentLength)) {
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
  bool _containsStatusCode(int? statusCode) {
    if (statusCode == null) {
      return false;
    }
    return any((element) => element.isInRange(statusCode));
  }
}
