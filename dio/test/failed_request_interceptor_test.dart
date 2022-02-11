import 'package:dio/dio.dart';
import 'package:sentry_dio/src/failed_request_interceptor.dart';
import 'package:test/test.dart';

import 'mocks/mock_hub.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('interceptor send error', () {
    final interceptor = fixture.getSut();
    interceptor.onError(
      DioError(requestOptions: RequestOptions(path: '')),
      fixture.errorInterceptorHandler,
    );

    expect(fixture.errorInterceptorHandler.nextWasCalled, true);
    expect(fixture.hub.captureExceptionCalls.length, 1);
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

class MockedErrorInterceptorHandler implements ErrorInterceptorHandler {
  bool nextWasCalled = false;

  @override
  void next(DioError err) {
    nextWasCalled = true;
  }

  @override
  void noSuchMethod(Invocation invocation) {}
}
