// ignore_for_file: strict_raw_type

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
        _client = client;

  final HttpClientAdapter _client;
  final Hub _hub;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    // ignore: invalid_use_of_internal_member
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

    // ignore: invalid_use_of_internal_member
    span?.origin = SentryTraceOrigins.autoHttpDioHttpClientAdapter;

    // if the span is NoOp, we don't want to attach headers
    if (span is NoOpSentrySpan) {
      span = null;
    }

    span?.setData('http.request.method', options.method);
    urlDetails?.applyToSpan(span);

    ResponseBody? response;
    try {
      if (containsTargetOrMatchesRegExp(
        // ignore: invalid_use_of_internal_member
        _hub.options.tracePropagationTargets,
        options.uri.toString(),
      )) {
        if (span != null) {
          addSentryTraceHeaderFromSpan(span, options.headers);
          addBaggageHeaderFromSpan(
            span,
            options.headers,
            // ignore: invalid_use_of_internal_member
            logger: _hub.options.logger,
          );
        } else {
          // ignore: invalid_use_of_internal_member
          final scope = _hub.scope;
          // ignore: invalid_use_of_internal_member
          final propagationContext = scope.propagationContext;

          final traceHeader = propagationContext.toSentryTrace();
          addSentryTraceHeader(traceHeader, options.headers);

          final baggage = propagationContext.baggage;
          if (baggage != null) {
            final baggageHeader = SentryBaggageHeader.fromBaggage(baggage);
            addBaggageHeader(
              baggageHeader,
              options.headers,
              // ignore: invalid_use_of_internal_member
              logger: _hub.options.logger,
            );
          }
        }
      }

      response = await _client.fetch(options, requestStream, cancelFuture);
      span?.status = SpanStatus.fromHttpStatusCode(response.statusCode);
      span?.setData('http.response.status_code', response.statusCode);
      final contentLengthHeader =
          // ignore: invalid_use_of_internal_member
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
