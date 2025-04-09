// ignore_for_file: strict_raw_type, invalid_use_of_internal_member

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';

/// A [Dio](https://pub.dev/packages/dio)-package compatible HTTP client adapter
/// which adds support to Sentry Performance feature.
/// https://develop.sentry.dev/sdk/performance
class TracingClientAdapter implements HttpClientAdapter {
  // ignore: public_member_api_docs
  TracingClientAdapter({required HttpClientAdapter client, Hub? hub})
      : _hub = hub ?? HubAdapter(),
        _client = client {
    if (_hub.options.isTracingEnabled()) {
      _hub.options.sdk.addIntegration('DioNetworkTracing');
    }
  }

  final HttpClientAdapter _client;
  final Hub _hub;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    final urlDetails = HttpSanitizer.sanitizeUrl(options.uri.toString());

    var description = options.method;
    if (urlDetails != null) {
      description += ' ${urlDetails.urlOrFallback}';
    }

    // see https://develop.sentry.dev/sdk/performance/#header-sentry-trace
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
      _hub.options.tracePropagationTargets,
      options.uri.toString(),
    )) {
      addTracingHeadersToHttpHeader(options.headers, span: span, hub: _hub);
    }

    span?.origin = SentryTraceOrigins.autoHttpDioHttpClientAdapter;
    span?.setData('http.request.method', options.method);
    urlDetails?.applyToSpan(span);

    ResponseBody? response;
    try {
      response = await _client.fetch(options, requestStream, cancelFuture);
      span?.status = SpanStatus.fromHttpStatusCode(response.statusCode);
      span?.setData('http.response.status_code', response.statusCode);
      final contentLengthHeader =
          HttpHeaderUtils.getContentLength(response.headers);
      if (contentLengthHeader != null) {
        span?.setData('http.response_content_length', contentLengthHeader);
      }
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
