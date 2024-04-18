// ignore_for_file: public_member_api_docs, deprecated_member_use

import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';

class FailedRequestInterceptor extends Interceptor {
  FailedRequestInterceptor({
    Hub? hub,
    List<SentryStatusCode> failedRequestStatusCodes =
        SentryHttpClient.defaultFailedRequestStatusCodes,
    List<String> failedRequestTargets =
        SentryHttpClient.defaultFailedRequestTargets,
    bool? captureFailedRequests,
  })  : _hub = hub ?? HubAdapter(),
        _failedRequestStatusCodes = failedRequestStatusCodes,
        _failedRequestTargets = failedRequestTargets,
        _captureFailedRequests = captureFailedRequests;

  final Hub _hub;
  final List<SentryStatusCode> _failedRequestStatusCodes;
  final List<String> _failedRequestTargets;
  final bool? _captureFailedRequests;

  @override
  Future<void> onError(
    DioError err,
    ErrorInterceptorHandler handler,
  ) async {
    // ignore: invalid_use_of_internal_member
    final cfr = _captureFailedRequests ?? _hub.options.captureFailedRequests;

    final containsStatusCode =
        _failedRequestStatusCodes._containsStatusCode(err.response?.statusCode);
    final containsRequestTarget = containsTargetOrMatchesRegExp(
      _failedRequestTargets,
      err.requestOptions.path,
    );

    if (cfr && containsStatusCode && containsRequestTarget) {
      final mechanism = Mechanism(type: 'SentryDioClientAdapter');
      final throwableMechanism = ThrowableMechanism(mechanism, err);

      _hub.getSpan()?.throwable = err;

      await _hub.captureException(throwableMechanism);
    }
    handler.next(err);
  }
}

extension _ListX on List<SentryStatusCode> {
  bool _containsStatusCode(int? statusCode) {
    if (statusCode == null) {
      return false;
    }
    return any((element) => element.isInRange(statusCode));
  }
}
