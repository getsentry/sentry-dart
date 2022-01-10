import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';

/// A transformer which wraps transforming in spans
class SentryTransformer implements Transformer {
  // ignore: public_member_api_docs
  SentryTransformer({required Transformer transformer, Hub? hub})
      : _hub = hub ?? HubAdapter(),
        _transformer = transformer;

  final Transformer _transformer;
  final Hub _hub;

  @override
  Future<String> transformRequest(RequestOptions options) async {
    final span = _hub.getSpan()?.startChild(
          'serialize',
          description: 'Dio.transformRequest: ${options.method} ${options.uri}',
        );
    try {
      final request = await _transformer.transformRequest(options);
      await span?.finish(status: SpanStatus.ok());
      return request;
    } catch (_) {
      await span?.finish(status: SpanStatus.internalError());
      rethrow;
    }
  }

  @override
  // ignore: strict_raw_type
  Future transformResponse(
    RequestOptions options,
    ResponseBody response,
  ) async {
    final span = _hub.getSpan()?.startChild(
          'serialize',
          description:
              'Dio.transformResponse: ${options.method} ${options.uri}',
        );
    try {
      final dynamic transformedResponse =
          await _transformer.transformResponse(options, response);
      await span?.finish(status: SpanStatus.ok());
      return transformedResponse;
    } catch (_) {
      await span?.finish(status: SpanStatus.internalError());
      rethrow;
    }
  }
}
