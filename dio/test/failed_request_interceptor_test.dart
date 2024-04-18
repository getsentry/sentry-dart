// ignore_for_file: deprecated_member_use

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
    final requestOptions = RequestOptions(path: 'https://example.com');
    final error = DioError(
      requestOptions: requestOptions,
      response: Response(statusCode: 500, requestOptions: requestOptions),
    );

    final sut = fixture.getSut();
    await sut.onError(error, fixture.errorInterceptorHandler);

    expect(fixture.errorInterceptorHandler.nextWasCalled, true);
    expect(fixture.hub.captureExceptionCalls.length, 1);

    final throwable =
        fixture.hub.captureExceptionCalls.first.throwable as ThrowableMechanism;
    expect(throwable.mechanism.type, 'SentryDioClientAdapter');
    expect(throwable.throwable, error);
  });

  test('do not capture if captureFailedRequests false', () async {
    final requestOptions = RequestOptions(path: 'https://example.com');
    final error = DioError(
      requestOptions: requestOptions,
      response: Response(statusCode: 500, requestOptions: requestOptions),
    );

    fixture.hub.options.captureFailedRequests = false;

    final sut = fixture.getSut();
    await sut.onError(error, fixture.errorInterceptorHandler);

    expect(fixture.errorInterceptorHandler.nextWasCalled, true);
    expect(fixture.hub.captureExceptionCalls.length, 0);
  });

  test('do capture if captureFailedRequests override is true', () async {
    final requestOptions = RequestOptions(path: 'https://example.com');
    final error = DioError(
      requestOptions: requestOptions,
      response: Response(statusCode: 500, requestOptions: requestOptions),
    );

    fixture.hub.options.captureFailedRequests = false;

    final sut = fixture.getSut(captureFailedRequests: true);
    await sut.onError(error, fixture.errorInterceptorHandler);

    expect(fixture.errorInterceptorHandler.nextWasCalled, true);
    expect(fixture.hub.captureExceptionCalls.length, 1);
  });

  test('do not capture if captureFailedRequests override false', () async {
    final requestOptions = RequestOptions(path: 'https://example.com');
    final error = DioError(
      requestOptions: requestOptions,
      response: Response(statusCode: 500, requestOptions: requestOptions),
    );

    fixture.hub.options.captureFailedRequests = true;

    final sut = fixture.getSut(captureFailedRequests: false);
    await sut.onError(error, fixture.errorInterceptorHandler);

    expect(fixture.errorInterceptorHandler.nextWasCalled, true);
    expect(fixture.hub.captureExceptionCalls.length, 0);
  });

  test('capture in range failedRequestStatusCodes', () async {
    final requestOptions = RequestOptions(path: 'https://example.com');
    final error = DioError(
      requestOptions: requestOptions,
      response: Response(statusCode: 404, requestOptions: requestOptions),
    );

    fixture.hub.options.captureFailedRequests = true;

    final sut = fixture.getSut(
      failedRequestStatusCodes: [SentryStatusCode(404)],
    );
    await sut.onError(error, fixture.errorInterceptorHandler);

    expect(fixture.errorInterceptorHandler.nextWasCalled, true);
    expect(fixture.hub.captureExceptionCalls.first, isNotNull);
    expect(fixture.hub.captureExceptionCalls.first.throwable, isNotNull);
  });

  test('do not capture out of range failedRequestStatusCodes', () async {
    final requestOptions = RequestOptions(path: 'https://example.com');
    final error = DioError(
      requestOptions: requestOptions,
      response: Response(statusCode: 502, requestOptions: requestOptions),
    );

    fixture.hub.options.captureFailedRequests = true;

    final sut = fixture.getSut(
      failedRequestStatusCodes: [SentryStatusCode(404)],
    );
    await sut.onError(error, fixture.errorInterceptorHandler);

    expect(fixture.errorInterceptorHandler.nextWasCalled, true);
    expect(fixture.hub.captureExceptionCalls.length, 0);
  });

  test('don not capture not matching target', () async {
    final requestOptions = RequestOptions(path: 'https://example.com');
    final error = DioError(
      requestOptions: requestOptions,
      response: Response(statusCode: 502, requestOptions: requestOptions),
    );

    fixture.hub.options.captureFailedRequests = true;

    final sut = fixture.getSut(
      failedRequestTargets: ['myapi.com'],
    );
    await sut.onError(error, fixture.errorInterceptorHandler);

    expect(fixture.errorInterceptorHandler.nextWasCalled, true);
    expect(fixture.hub.captureExceptionCalls.length, 0);
  });
}

class Fixture {
  MockHub hub = MockHub();
  MockedErrorInterceptorHandler errorInterceptorHandler =
      MockedErrorInterceptorHandler();

  FailedRequestInterceptor getSut({
    List<SentryStatusCode> failedRequestStatusCodes = const [
      SentryStatusCode.defaultRange(),
    ],
    List<String> failedRequestTargets = const ['.*'],
    bool? captureFailedRequests,
  }) {
    return FailedRequestInterceptor(
      hub: hub,
      failedRequestStatusCodes: failedRequestStatusCodes,
      failedRequestTargets: failedRequestTargets,
      captureFailedRequests: captureFailedRequests,
    );
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
