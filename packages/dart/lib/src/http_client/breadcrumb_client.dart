import 'package:http/http.dart';
import 'package:meta/meta.dart';

import '../protocol.dart';
import '../hub.dart';
import '../hub_adapter.dart';
import '../utils.dart';
import '../utils/breadcrumb_log_level.dart';
import '../utils/url_details.dart';
import '../utils/http_sanitizer.dart';
import 'network_details_capture.dart';

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
  BreadcrumbClient({
    Client? client,
    Hub? hub,
    @internal NetworkDetailsCapture? networkDetailsCapture,
  })  : _hub = hub ?? HubAdapter(),
        _client = client ?? Client(),
        _networkDetailsCapture = networkDetailsCapture;

  final Client _client;
  final Hub _hub;
  final NetworkDetailsCapture? _networkDetailsCapture;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    // See https://develop.sentry.dev/sdk/event-payloads/breadcrumbs/

    var requestHadException = false;
    int? statusCode;
    String? reason;
    int? responseBodySize;
    Map<String, dynamic>? requestDetail;
    Map<String, dynamic>? responseDetail;
    DateTime? responseTimestamp;

    final stopwatch = Stopwatch();
    stopwatch.start();

    final capture = _networkDetailsCapture;
    final captureNetworkDetails =
        capture != null && capture.shouldCapture(request.url);

    try {
      StreamedResponse response;
      try {
        response = await _client.send(request);
      } catch (_) {
        // Only a transport-level failure counts as a request exception for
        // breadcrumb-level purposes; a capture failure below (once we
        // already have a real response) shouldn't mark a successful
        // request as an error.
        requestHadException = true;
        rethrow;
      } finally {
        // Stopped as soon as headers arrive (success or failure) rather
        // than in the outer `finally`, so `requestDuration` measures
        // time-to-headers consistently whether or not network details are
        // captured. Capturing the response body below can take arbitrarily
        // long (e.g. downloading a large body) and shouldn't inflate the
        // measured duration.
        stopwatch.stop();
        // Breadcrumb.http anchors start_timestamp/end_timestamp on the
        // timestamp passed below, so it needs to be taken at the same
        // moment as the stopwatch above rather than left to default to
        // "now" when the breadcrumb is built in the outer `finally` -
        // otherwise both timestamps would drift by however long response
        // capture takes, even though duration wouldn't.
        responseTimestamp = getUtcDateTime();
      }

      statusCode = response.statusCode;
      reason = response.reasonPhrase;
      responseBodySize = response.contentLength;

      if (captureNetworkDetails) {
        final result = await capture.captureResponse(response);
        response = result.$1;
        responseDetail = result.$2;
      }

      return response;
    } finally {
      // Captured after `_client.send` returns (or throws) rather than
      // before, so that headers set by clients further down the chain
      // (e.g. TracingClient's sentry-trace/baggage) are reflected instead
      // of a pre-dispatch snapshot.
      if (captureNetworkDetails) {
        requestDetail = capture.captureRequest(request);
      }

      final urlDetails =
          HttpSanitizer.sanitizeUrl(request.url.toString()) ?? UrlDetails();

      SentryLevel? level;
      if (requestHadException) {
        level = SentryLevel.error;
      } else if (statusCode != null) {
        level = getBreadcrumbLogLevelFromHttpStatusCode(statusCode);
      }

      var breadcrumb = Breadcrumb.http(
        level: level,
        url: Uri.parse(urlDetails.urlOrFallback),
        method: request.method,
        statusCode: statusCode,
        reason: reason,
        requestDuration: stopwatch.elapsed,
        timestamp: responseTimestamp,
        requestBodySize: request.contentLength,
        responseBodySize: responseBodySize,
        httpQuery: urlDetails.query,
        httpFragment: urlDetails.fragment,
      );

      if (requestDetail != null) {
        breadcrumb.data?['request'] = requestDetail;
      }
      if (responseDetail != null) {
        breadcrumb.data?['response'] = responseDetail;
      }

      await _hub.addBreadcrumb(breadcrumb);
    }
  }

  @override
  void close() => _client.close();
}
