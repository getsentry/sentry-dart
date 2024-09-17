import 'package:http/http.dart';
import '../../sentry.dart';
import '../hub.dart';
import '../hub_adapter.dart';
import '../protocol.dart';
import '../sentry_trace_origins.dart';
import '../tracing.dart';
import '../utils/http_deep_copy_streamed_response.dart';
import '../utils/tracing_utils.dart';
import '../utils/http_sanitizer.dart';

/// A [http](https://pub.dev/packages/http)-package compatible HTTP client
/// which adds support to Sentry Performance feature.
/// https://develop.sentry.dev/sdk/performance
class TracingClient extends BaseClient {
  TracingClient({Client? client, Hub? hub})
      : _hub = hub ?? HubAdapter(),
        _client = client ?? Client();

  final Client _client;
  final Hub _hub;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    // see https://develop.sentry.dev/sdk/performance/#header-sentry-trace
    int? statusCode;
    final stopwatch = Stopwatch();
    stopwatch.start();

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
    span?.origin = SentryTraceOrigins.autoHttpHttp;

    // if the span is NoOp, we don't want to attach headers
    if (span is NoOpSentrySpan) {
      span = null;
    }

    span?.setData('http.request.method', request.method);
    urlDetails?.applyToSpan(span);

    StreamedResponse? response;
    List<StreamedResponse> copiedResponses = [];
    try {
      if (containsTargetOrMatchesRegExp(
          _hub.options.tracePropagationTargets, request.url.toString())) {
        if (span != null) {
          addSentryTraceHeaderFromSpan(span, request.headers);
          addBaggageHeaderFromSpan(
            span,
            request.headers,
            logger: _hub.options.logger,
          );
        } else {
          final scope = _hub.scope;
          final propagationContext = scope.propagationContext;

          final traceHeader = propagationContext.toSentryTrace();
          addSentryTraceHeader(traceHeader, request.headers);

          final baggage = propagationContext.baggage;
          if (baggage != null) {
            final baggageHeader = SentryBaggageHeader.fromBaggage(baggage);
            addBaggageHeader(baggageHeader, request.headers,
                logger: _hub.options.logger);
          }
        }
      }

      response = await _client.send(request);
      copiedResponses = await deepCopyStreamedResponse(response, 2);
      statusCode = copiedResponses[0].statusCode;
      span?.setData('http.response.status_code', copiedResponses[1].statusCode);
      span?.setData(
          'http.response_content_length', copiedResponses[1].contentLength);
      if (_hub.options.sendDefaultPii &&
          _hub.options.maxResponseBodySize
              .shouldAddBody(response.contentLength!)) {
        final responseBody = await copiedResponses[1].stream.bytesToString();
        span?.setData('http.response_content', responseBody);
      }
      span?.status =
          SpanStatus.fromHttpStatusCode(copiedResponses[1].statusCode);
    } catch (exception) {
      span?.throwable = exception;
      span?.status = SpanStatus.internalError();

      rethrow;
    } finally {
      await span?.finish();
      stopwatch.stop();
      await captureEvent(
        _hub,
        request: request,
        requestDuration: stopwatch.elapsed,
        response: copiedResponses.isNotEmpty ? copiedResponses[1] : null,
        reason: 'HTTP Client Event with status code: $statusCode',
      );
    }
    return copiedResponses[0];
  }

  @override
  void close() => _client.close();
}
