import 'package:http/http.dart';

import '../../sentry.dart';

/// Client that adds Sentry trace headers even with performance disabled.
class TracingWithoutPerformanceClient extends BaseClient {
  TracingWithoutPerformanceClient({Client? client, Hub? hub})
      : _hub = hub ?? HubAdapter(),
        _client = client ?? Client();

  final Client _client;
  final Hub _hub;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (containsTargetOrMatchesRegExp(
        _hub.options.tracePropagationTargets, request.url.toString())) {
      addTracingHeadersToHttpHeader(request.headers, hub: _hub);
    }
    return _client.send(request);
  }

  @override
  void close() => _client.close();
}
