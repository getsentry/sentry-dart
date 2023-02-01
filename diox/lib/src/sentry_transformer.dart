import 'package:diox/diox.dart';
import 'package:sentry/sentry.dart';

/// A transformer which wraps transforming in spans
class SentryTransformer implements Transformer {
  static const _serializeOp = 'serialize.http.client';

  // ignore: public_member_api_docs
  SentryTransformer({required Transformer transformer, Hub? hub})
      : _hub = hub ?? HubAdapter(),
        _transformer = transformer;

  final Transformer _transformer;
  final Hub _hub;

  @override
  Future<String> transformRequest(RequestOptions options) async {
    final span = _hub.getSpan()?.startChild(
          _serializeOp,
          description: '${options.method} ${options.uri}',
        );
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
    final span = _hub.getSpan()?.startChild(
          _serializeOp,
          description: '${options.method} ${options.uri}',
        );
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
