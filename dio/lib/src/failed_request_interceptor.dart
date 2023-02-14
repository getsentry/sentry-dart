// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';

class FailedRequestInterceptor extends Interceptor {
  FailedRequestInterceptor({
    Hub? hub,
    List<SentryStatusCode> failedRequestStatusCodes = const [],
  })  : _hub = hub ?? HubAdapter(),
        _failedRequestStatusCodes = failedRequestStatusCodes;

  final Hub _hub;
  final List<SentryStatusCode> _failedRequestStatusCodes;

  @override
  Future<void> onError(
    DioError err,
    ErrorInterceptorHandler handler,
  ) async {
    if (_failedRequestStatusCodes.isEmpty ||
        _failedRequestStatusCodes
            .containsStatusCode(err.response?.statusCode)) {
      final mechanism = Mechanism(type: 'SentryDioClientAdapter');
      final throwableMechanism = ThrowableMechanism(mechanism, err);

      _hub.getSpan()?.throwable = err;

      await _hub.captureException(throwableMechanism);
    }
    handler.next(err);
  }
}

extension _ListX on List<SentryStatusCode> {
  bool containsStatusCode(int? statusCode) {
    if (statusCode == null) {
      return false;
    }
    return any((element) => element.isInRange(statusCode));
  }
}
