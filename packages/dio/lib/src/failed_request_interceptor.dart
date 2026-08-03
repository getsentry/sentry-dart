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

    // ignore: invalid_use_of_internal_member
    if (isSentryRequestUrl(err.requestOptions.uri.toString(), _hub.options)) {
      handler.next(err);
      return;
    }

    final statusCode = err.response?.statusCode;
    // A connection-level failure — timeout, DNS error, bad certificate — has no
    // status code to match against, so there is nothing to filter on. A
    // cancellation is a deliberate user action, not a failure.
    final isFailure = statusCode == null
        ? err.type != DioExceptionType.cancel
        : _failedRequestStatusCodes._containsStatusCode(statusCode);

    // Match on the resolved URL, not `requestOptions.path`, which is relative
    // to `baseUrl` and would never match a host-based target.
    final containsRequestTarget = containsTargetOrMatchesRegExp(
      _failedRequestTargets,
      err.requestOptions.uri.toString(),
    );

    if (cfr && isFailure && containsRequestTarget) {
      final mechanism = Mechanism(
        type: 'SentryDioClientAdapter',
        handled: true,
      );
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
