// ignore_for_file: strict_raw_type

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';

/// A [Dio](https://pub.dev/packages/dio)-package compatible HTTP client adapter
/// which adds support to Sentry Performance feature.
/// https://develop.sentry.dev/sdk/performance
class TracingClientAdapter extends HttpClientAdapter {
  // ignore: public_member_api_docs
  TracingClientAdapter({required HttpClientAdapter client, Hub? hub})
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
    // see https://develop.sentry.dev/sdk/performance/#header-sentry-trace
    final currentSpan = _hub.getSpan();
    final span = currentSpan?.startChild(
      'http.client',
      description: '${options.method} ${options.uri}',
    );

    ResponseBody? response;
    try {
      if (span != null) {
        if (containsTracePropagationTarget(
          // ignore: invalid_use_of_internal_member
          _hub.options.tracePropagationTargets,
          options.uri.toString(),
        )) {
          addSentryTraceHeader(span, options.headers);
          addBaggageHeader(
            span,
            options.headers,
            // ignore: invalid_use_of_internal_member
            logger: _hub.options.logger,
          );
        }
      }

      response = await _client.fetch(options, requestStream, cancelFuture);
      span?.status = SpanStatus.fromHttpStatusCode(response.statusCode ?? -1);
    } catch (exception) {
      span?.throwable = exception;
      span?.status = const SpanStatus.internalError();

      rethrow;
    } finally {
      await span?.finish();
    }
    return response;
  }

  @override
  void close({bool force = false}) => _client.close(force: force);
}
