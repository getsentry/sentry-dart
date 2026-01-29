// ignore_for_file: strict_raw_type, invalid_use_of_internal_member

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';

/// A [Dio](https://pub.dev/packages/dio)-package compatible HTTP client adapter
/// which adds support to Sentry Performance feature. If tracing is disabled
/// generated spans will be no-op. This client also handles adding the
/// Sentry trace headers to the HTTP request header.
/// https://develop.sentry.dev/sdk/performance
class TracingClientAdapter implements HttpClientAdapter {
  // ignore: public_member_api_docs
  static const String integrationName = 'HTTPNetworkTracing';

  // ignore: public_member_api_docs
  TracingClientAdapter({required HttpClientAdapter client, Hub? hub})
      : _hub = hub ?? HubAdapter(),
        _client = client {
    _spanFactory = _hub.options.spanFactory;
    if (_hub.options.isTracingEnabled()) {
      _hub.options.sdk.addIntegration(integrationName);
    }
  }

  final HttpClientAdapter _client;
  final Hub _hub;
  late final InstrumentationSpanFactory _spanFactory;

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
    final parentSpan = _spanFactory.getSpan(_hub);
    final instrumentationSpan = _spanFactory.createSpan(
      parentSpan,
      'http.client',
      description: description,
    );

    // Regardless whether tracing is enabled or not, we always want to attach
    // Sentry trace headers (tracing without performance).
    if (containsTargetOrMatchesRegExp(
      _hub.options.tracePropagationTargets,
      options.uri.toString(),
    )) {
      // Extract underlying ISentrySpan for tracing headers, or use propagation context
      final sentrySpan = instrumentationSpan is LegacyInstrumentationSpan
          ? instrumentationSpan.spanReference
          : null;
      addTracingHeadersToHttpHeader(options.headers, _hub, span: sentrySpan);
    }

    instrumentationSpan?.origin = SentryTraceOrigins.autoHttpDioHttpClientAdapter;
    instrumentationSpan?.setData('http.request.method', options.method);
    urlDetails?.applyToSpan(instrumentationSpan);

    ResponseBody? response;
    try {
      response = await _client.fetch(options, requestStream, cancelFuture);
      instrumentationSpan?.status =
          SpanStatus.fromHttpStatusCode(response.statusCode);
      instrumentationSpan?.setData(
        'http.response.status_code',
        response.statusCode,
      );
      final contentLengthHeader =
          HttpHeaderUtils.getContentLength(response.headers);
      if (contentLengthHeader != null) {
        instrumentationSpan?.setData(
          'http.response_content_length',
          contentLengthHeader,
        );
      }
    } catch (exception) {
      instrumentationSpan?.throwable = exception;
      instrumentationSpan?.status = const SpanStatus.internalError();

      rethrow;
    } finally {
      await instrumentationSpan?.finish();
    }
    return response;
  }

  @override
  void close({bool force = false}) => _client.close(force: force);
}
