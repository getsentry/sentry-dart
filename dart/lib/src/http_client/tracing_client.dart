import 'package:http/http.dart';

import '../hub.dart';
import '../hub_adapter.dart';
import '../protocol.dart';
import '../sentry_trace_origins.dart';
import '../tracing.dart';
import '../utils/add_tracing_headers_to_http_request.dart';
import '../utils/http_sanitizer.dart';
import '../utils/tracing_utils.dart';

/// A [http](https://pub.dev/packages/http)-package compatible HTTP client
/// which adds support to Sentry Performance feature.
/// https://develop.sentry.dev/sdk/performance
class TracingClient extends BaseClient {
  TracingClient({Client? client, Hub? hub})
      : _hub = hub ?? HubAdapter(),
        _client = client ?? Client() {
    if (_hub.options.isTracingEnabled()) {
      _hub.options.sdk.addIntegration('HTTPNetworkTracing');
    }
  }

  final Client _client;
  final Hub _hub;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    // see https://develop.sentry.dev/sdk/performance/#header-sentry-trace

    final urlDetails = HttpSanitizer.sanitizeUrl(request.url.toString());

    var description = request.method;
    if (urlDetails != null) {
      description += ' ${urlDetails.urlOrFallback}';
    }

    final currentSpan = _hub.getSpan();
    var span = currentSpan?.startChild(
      'http.client',
      description: description,
    );

    if (span is NoOpSentrySpan) {
      span = null;
    }

    // Regardless whether tracing is enabled or not, we always want to attach
    // Sentry trace headers (tracing without performance).
    if (containsTargetOrMatchesRegExp(
        _hub.options.tracePropagationTargets, request.url.toString())) {
      addTracingHeadersToHttpHeader(request.headers, span: span, hub: _hub);
    }

    span?.origin = SentryTraceOrigins.autoHttpHttp;
    span?.setData('http.request.method', request.method);
    urlDetails?.applyToSpan(span);

    StreamedResponse? response;
    try {
      response = await _client.send(request);
      span?.setData('http.response.status_code', response.statusCode);
      span?.setData('http.response_content_length', response.contentLength);
      span?.status = SpanStatus.fromHttpStatusCode(response.statusCode);
    } catch (exception) {
      span?.throwable = exception;
      span?.status = SpanStatus.internalError();

      rethrow;
    } finally {
      await span?.finish();
    }
    return response;
  }

  @override
  void close() => _client.close();
}
