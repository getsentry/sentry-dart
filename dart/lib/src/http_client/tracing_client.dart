import 'package:http/http.dart';
import '../hub.dart';
import '../hub_adapter.dart';
import '../protocol.dart';

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
    final span = currentSpan?.startChild(
      'http.client',
      description: '${request.method} ${request.url}',
    );

    StreamedResponse? response;
    try {
      if (span != null) {
        final traceHeader = span.toSentryTrace();
        request.headers[traceHeader.name] = traceHeader.value;
      }

      // TODO: tracingOrigins support

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
