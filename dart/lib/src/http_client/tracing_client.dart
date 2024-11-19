import 'package:http/http.dart';
import '../../sentry.dart';
import '../utils/streamed_response_copier.dart';

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

    StreamedResponse? originalResponse;
    final hint = Hint();
    // List<StreamedResponse> copiedResponses = [];
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

      originalResponse = await _client.send(request);
      final copier = StreamedResponseCopier(originalResponse);
      originalResponse = copier.copy();
      final copiedResponse = copier.copy();

      span?.setData('http.response.status_code', originalResponse.statusCode);
      span?.setData(
          'http.response_content_length', originalResponse.contentLength);
      span?.status = SpanStatus.fromHttpStatusCode(originalResponse.statusCode);

      hint.set(TypeCheckHint.httpResponse, copiedResponse);
    } catch (exception) {
      span?.throwable = exception;
      span?.status = SpanStatus.internalError();

      rethrow;
    } finally {
      await span?.finish(hint: hint);
      stopwatch.stop();
    }
    return originalResponse;
  }

  @override
  void close() => _client.close();
}
