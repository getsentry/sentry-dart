// ignore_for_file: strict_raw_type

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';

/// Client that adds Sentry trace headers even with performance disabled.
class TracingWithoutPerformanceClient implements HttpClientAdapter {
  // ignore: public_member_api_docs
  TracingWithoutPerformanceClient({required HttpClientAdapter client, Hub? hub})
      : _hub = hub ?? HubAdapter(),
        _client = client;

  final HttpClientAdapter _client;
  final Hub _hub;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    if (containsTargetOrMatchesRegExp(
      // ignore: invalid_use_of_internal_member
      _hub.options.tracePropagationTargets,
      options.uri.toString(),
    )) {
      // ignore: invalid_use_of_internal_member
      addTracingHeadersToHttpHeader(options.headers, hub: _hub);
    }
    return _client.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => _client.close(force: force);
}
