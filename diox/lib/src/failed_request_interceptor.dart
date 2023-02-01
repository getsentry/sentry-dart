// ignore_for_file: public_member_api_docs

import 'package:diox/diox.dart';
import 'package:sentry/sentry.dart';

class FailedRequestInterceptor extends Interceptor {
  FailedRequestInterceptor({Hub? hub}) : _hub = hub ?? HubAdapter();

  final Hub _hub;

  @override
  Future<void> onError(
    DioError err,
    ErrorInterceptorHandler handler,
  ) async {
    final mechanism = Mechanism(type: 'SentryDioxClientAdapter');
    final throwableMechanism = ThrowableMechanism(mechanism, err);

    _hub.getSpan()?.throwable = err;

    await _hub.captureException(throwableMechanism);

    handler.next(err);
  }
}
