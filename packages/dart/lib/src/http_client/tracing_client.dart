import 'package:http/http.dart';

import '../hub.dart';
import '../hub_adapter.dart';
import '../protocol.dart';
import '../sentry_trace_origins.dart';
import '../tracing/instrumentation/instrumentation.dart';
import '../utils/http_sanitizer.dart';
import '../utils/tracing_utils.dart';

/// A [http](https://pub.dev/packages/http)-package compatible HTTP client
/// which adds support to Sentry Performance feature. If tracing is disabled
/// generated spans will be no-op. This client also handles adding the
/// Sentry trace headers to the HTTP request header.
/// https://develop.sentry.dev/sdk/performance
class TracingClient extends BaseClient {
  static const String integrationName = 'HTTPNetworkTracing';

  TracingClient({Client? client, Hub? hub})
      : _hub = hub ?? HubAdapter(),
        _client = client ?? Client() {
    _spanFactory = _hub.options.spanFactory;
    if (_hub.options.isTracingEnabled()) {
      _hub.options.sdk.addIntegration(integrationName);
    }
  }

  final Client _client;
  final Hub _hub;
  late final InstrumentationSpanFactory _spanFactory;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    // see https://develop.sentry.dev/sdk/performance/#header-sentry-trace
    final urlDetails = HttpSanitizer.sanitizeUrl(request.url.toString());

    var description = request.method;
    if (urlDetails != null) {
      description += ' ${urlDetails.urlOrFallback}';
    }

    final parentSpan = _spanFactory.getSpan(_hub);
    final instrumentationSpan = _spanFactory.createSpan(
      parentSpan,
      'http.client',
      description: description,
    );

    // Regardless whether tracing is enabled or not, we always want to attach
    // Sentry trace headers (tracing without performance).
    if (containsTargetOrMatchesRegExp(
        _hub.options.tracePropagationTargets, request.url.toString())) {
      // Extract underlying ISentrySpan for tracing headers, or use propagation context
      final sentrySpan = instrumentationSpan is LegacyInstrumentationSpan
          ? instrumentationSpan.spanReference
          : null;
      addTracingHeadersToHttpHeader(request.headers, _hub, span: sentrySpan);
    }

    instrumentationSpan?.origin = SentryTraceOrigins.autoHttpHttp;
    instrumentationSpan?.setData('http.request.method', request.method);
    urlDetails?.applyToInstrumentationSpan(instrumentationSpan);

    StreamedResponse? response;
    try {
      response = await _client.send(request);
      instrumentationSpan?.setData(
          'http.response.status_code', response.statusCode);
      instrumentationSpan?.setData(
          'http.response_content_length', response.contentLength);
      instrumentationSpan?.status =
          SpanStatus.fromHttpStatusCode(response.statusCode);
    } catch (exception) {
      instrumentationSpan?.throwable = exception;
      instrumentationSpan?.status = SpanStatus.internalError();

      rethrow;
    } finally {
      await instrumentationSpan?.finish();
    }
    return response;
  }

  @override
  void close() => _client.close();
}
