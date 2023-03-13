import 'package:http/http.dart';
import '../hub.dart';
import '../hub_adapter.dart';
import '../protocol.dart';
import '../tracing.dart';
import '../utils/tracing_utils.dart';

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
    final currentSpan = _hub.getSpan();
    var span = currentSpan?.startChild(
      'http.client',
      description: '${request.method} ${request.url}',
    );

    // span.set_data("url", parsed_url.url)
    // span.setData("http.query", parsedUrl.query)
    // span.set_data("http.fragment", parsed_url.fragment)

    // if the span is NoOp, we don't want to attach headers
    if (span is NoOpSentrySpan) {
      span = null;
    }

    span?.setData('method', request.method);
    span?.setData('url', request.url);

    StreamedResponse? response;
    try {
      if (span != null) {
        if (containsTargetOrMatchesRegExp(
            _hub.options.tracePropagationTargets, request.url.toString())) {
          addSentryTraceHeader(span, request.headers);
          addBaggageHeader(
            span,
            request.headers,
            logger: _hub.options.logger,
          );
        }
      }

      response = await _client.send(request);
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
