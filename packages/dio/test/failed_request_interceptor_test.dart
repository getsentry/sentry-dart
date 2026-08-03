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

  test('capture connection error without a response', () async {
    final error = DioError.connectionError(
      requestOptions: RequestOptions(path: 'https://example.com'),
      reason: "Failed host lookup: 'example.com'",
    );

    fixture.hub.options.captureFailedRequests = true;

    final sut = fixture.getSut();
    await sut.onError(error, fixture.errorInterceptorHandler);

    expect(fixture.hub.captureExceptionCalls.length, 1);
  });

  test('capture timeout without a response', () async {
    final error = DioError.connectionTimeout(
      timeout: Duration(seconds: 5),
      requestOptions: RequestOptions(path: 'https://example.com'),
    );

    fixture.hub.options.captureFailedRequests = true;

    final sut = fixture.getSut();
    await sut.onError(error, fixture.errorInterceptorHandler);

    expect(fixture.hub.captureExceptionCalls.length, 1);
  });

  test('do not capture a cancelled request', () async {
    final error = DioError.requestCancelled(
      requestOptions: RequestOptions(path: 'https://example.com'),
      reason: 'user navigated away',
    );

    fixture.hub.options.captureFailedRequests = true;

    final sut = fixture.getSut();
    await sut.onError(error, fixture.errorInterceptorHandler);

    expect(fixture.hub.captureExceptionCalls.length, 0);
  });

  test('do not capture connection error outside the targets', () async {
    final error = DioError.connectionError(
      requestOptions: RequestOptions(path: 'https://example.com'),
      reason: "Failed host lookup: 'example.com'",
    );

    fixture.hub.options.captureFailedRequests = true;

    final sut = fixture.getSut(failedRequestTargets: ['myapi.com']);
    await sut.onError(error, fixture.errorInterceptorHandler);

    expect(fixture.hub.captureExceptionCalls.length, 0);
  });

  test('capture target matching the base url', () async {
    final requestOptions = RequestOptions(
      path: '/foo/bar',
      baseUrl: 'https://myapi.com',
    );
    final error = DioError(
      requestOptions: requestOptions,
      response: Response(statusCode: 502, requestOptions: requestOptions),
    );

    fixture.hub.options.captureFailedRequests = true;

    final sut = fixture.getSut(failedRequestTargets: ['myapi.com']);
    await sut.onError(error, fixture.errorInterceptorHandler);

    expect(fixture.hub.captureExceptionCalls.length, 1);
  });

  test('don not capture not matching target', () async {
    final requestOptions = RequestOptions(path: 'https://example.com');
    final error = DioError(
      requestOptions: requestOptions,
      response: Response(statusCode: 502, requestOptions: requestOptions),
    );

    fixture.hub.options.captureFailedRequests = true;

    final sut = fixture.getSut(failedRequestTargets: ['myapi.com']);
    await sut.onError(error, fixture.errorInterceptorHandler);

    expect(fixture.errorInterceptorHandler.nextWasCalled, true);
    expect(fixture.hub.captureExceptionCalls.length, 0);
  });

  test('captured request is handled, so it does not end the session', () async {
    final requestOptions = RequestOptions(path: 'https://example.com');
    final error = DioError(
      requestOptions: requestOptions,
      response: Response(statusCode: 502, requestOptions: requestOptions),
    );

    fixture.hub.options.captureFailedRequests = true;

    final sut = fixture.getSut();
    await sut.onError(error, fixture.errorInterceptorHandler);

    final captured = fixture.hub.captureExceptionCalls.first.throwable;
    expect((captured as ThrowableMechanism).mechanism.handled, true);
  });

  test('do not capture a request to the dsn', () async {
    final dsnHost = Uri.parse(fixture.hub.options.dsn!).host;
    final requestOptions = RequestOptions(
      path: 'https://$dsnHost/api/1/envelope/',
    );
    final error = DioError(
      requestOptions: requestOptions,
      response: Response(statusCode: 502, requestOptions: requestOptions),
    );

    fixture.hub.options.captureFailedRequests = true;

    final sut = fixture.getSut();
    await sut.onError(error, fixture.errorInterceptorHandler);

    expect(fixture.errorInterceptorHandler.nextWasCalled, true);
    expect(fixture.hub.captureExceptionCalls.length, 0);
  });

  test('capture a host that merely contains the dsn host', () async {
    final dsnHost = Uri.parse(fixture.hub.options.dsn!).host;
    final requestOptions = RequestOptions(path: 'https://not-$dsnHost/foo');
    final error = DioError(
      requestOptions: requestOptions,
      response: Response(statusCode: 502, requestOptions: requestOptions),
    );

    fixture.hub.options.captureFailedRequests = true;

    final sut = fixture.getSut();
    await sut.onError(error, fixture.errorInterceptorHandler);

    expect(fixture.hub.captureExceptionCalls.length, 1);
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
