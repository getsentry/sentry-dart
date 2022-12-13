import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_dio/src/failed_request_interceptor.dart';
import 'package:test/test.dart';

import 'mocks/mock_hub.dart';
import 'mocks/no_such_method_provider.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('interceptor send error', () async {
    final interceptor = fixture.getSut();
    final error = DioError(requestOptions: RequestOptions(path: ''));
    await interceptor.onError(
      error,
      fixture.errorInterceptorHandler,
    );

    expect(fixture.errorInterceptorHandler.nextWasCalled, true);
    expect(fixture.hub.captureExceptionCalls.length, 1);

    final throwable =
        fixture.hub.captureExceptionCalls.first.throwable as ThrowableMechanism;
    expect(throwable.mechanism.type, 'SentryDioClientAdapter');
    expect(throwable.mechanism.handled, isNull);
    expect(throwable.throwable, error);
  });
}

class Fixture {
  MockHub hub = MockHub();
  MockedErrorInterceptorHandler errorInterceptorHandler =
      MockedErrorInterceptorHandler();

  FailedRequestInterceptor getSut() {
    return FailedRequestInterceptor(hub: hub);
  }
}

class MockedErrorInterceptorHandler
    with NoSuchMethodProvider
    implements ErrorInterceptorHandler {
  bool nextWasCalled = false;

  @override
  void next(DioError err) {
    nextWasCalled = true;
  }
}
