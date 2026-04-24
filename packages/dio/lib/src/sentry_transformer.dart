// ignore_for_file: invalid_use_of_internal_member

import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';

/// A transformer which wraps transforming in spans
class SentryTransformer implements Transformer {
  static const _serializeOp = 'serialize.http.client';

  // ignore: public_member_api_docs
  SentryTransformer({required Transformer transformer, Hub? hub})
      : _hub = hub ?? HubAdapter(),
        _transformer = transformer {
    _spanFactory = _hub.options.spanFactory;
  }

  final Transformer _transformer;
  final Hub _hub;
  late final InstrumentationSpanFactory _spanFactory;

  @override
  Future<String> transformRequest(RequestOptions options) async {
    final urlDetails = HttpSanitizer.sanitizeUrl(options.uri.toString());
    var description = options.method;
    if (urlDetails != null) {
      description += ' ${urlDetails.urlOrFallback}';
    }

    final parentSpan = _spanFactory.getSpan(_hub);
    final span = parentSpan != null
        ? _spanFactory.createSpan(
            parentSpan: parentSpan,
            operation: _serializeOp,
            description: description,
          )
        : null;

    span?.setData('http.request.method', options.method);
    span?.origin = SentryTraceOrigins.autoHttpDioTransformer;

    urlDetails?.applyToSpan(span);

    String? request;
    try {
      request = await _transformer.transformRequest(options);
      span?.status = const SpanStatus.ok();
    } catch (exception) {
      span?.throwable = exception;
      span?.status = const SpanStatus.internalError();
      rethrow;
    } finally {
      await span?.finish();
    }
    return request;
  }

  @override
  // ignore: strict_raw_type
  Future transformResponse(
    RequestOptions options,
    ResponseBody response,
  ) async {
    final urlDetails = HttpSanitizer.sanitizeUrl(options.uri.toString());
    var description = options.method;
    if (urlDetails != null) {
      description += ' ${urlDetails.urlOrFallback}';
    }

    final parentSpan = _spanFactory.getSpan(_hub);
    final span = parentSpan != null
        ? _spanFactory.createSpan(
            parentSpan: parentSpan,
            operation: _serializeOp,
            description: description,
          )
        : null;

    span?.setData('http.request.method', options.method);
    span?.origin = SentryTraceOrigins.autoHttpDioTransformer;

    urlDetails?.applyToSpan(span);

    dynamic transformedResponse;
    try {
      transformedResponse =
          await _transformer.transformResponse(options, response);
      span?.status = const SpanStatus.ok();
    } catch (exception) {
      span?.throwable = exception;
      span?.status = const SpanStatus.internalError();
      rethrow;
    } finally {
      await span?.finish();
    }
    return transformedResponse;
  }
}
