import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('DioEventProcessor only processes DioErrors', () {
    final sut = fixture.getSut();

    final event = SentryEvent(throwable: Exception());
    final processedEvent = sut.apply(event) as SentryEvent;

    expect(event, processedEvent);
  });

  test(
      'DioEventProcessor does not change anything '
      'if stacktrace is null and a request is present', () {
    final sut = fixture.getSut();

    final event = SentryEvent(
      throwable: DioError(
        requestOptions: RequestOptions(path: '/foo/bar'),
      ),
      request: SentryRequest(),
    );
    final processedEvent = sut.apply(event) as SentryEvent;

    expect(event.throwable, processedEvent.throwable);
    expect(event.request, processedEvent.request);
  });

  test('DioEventProcessor adds request', () {
    final sut = fixture.getSut(sendDefaultPii: true);

    final event = SentryEvent(
      throwable: DioError(
        requestOptions: requestOptions,
        response: Response<dynamic>(
          requestOptions: requestOptions,
          data: 'foobar',
        ),
      ),
    );
    final processedEvent = sut.apply(event) as SentryEvent;

    expect(processedEvent.throwable, event.throwable);
    expect(processedEvent.request?.method, 'GET');
    expect(processedEvent.request?.queryString, 'foo=bar');
    expect(processedEvent.request?.headers, <String, String>{
      'foo': 'bar',
      'content-type': 'application/json; charset=utf-8'
    });
    expect(processedEvent.request?.data, 'foobar');
  });

  test('DioEventProcessor adds request without pii', () {
    final sut = fixture.getSut(sendDefaultPii: false);

    final event = SentryEvent(
      throwable: DioError(
        requestOptions: requestOptions,
        response: Response<dynamic>(
          requestOptions: requestOptions,
          data: 'foobar',
        ),
      ),
    );
    final processedEvent = sut.apply(event) as SentryEvent;

    expect(processedEvent.throwable, event.throwable);
    expect(processedEvent.request?.method, 'GET');
    expect(processedEvent.request?.queryString, 'foo=bar');
    expect(processedEvent.request?.data, null);
    expect(processedEvent.request?.headers, <String, String>{});
  });

  test('DioEventProcessor adds request without pii', () {
    final sut = fixture.getSut(sendDefaultPii: false);

    final event = SentryEvent(
      throwable: DioError(
        error: Exception('foo bar'),
        requestOptions: requestOptions,
        response: Response<dynamic>(
          requestOptions: requestOptions,
          data: 'foobar',
        ),
      )..stackTrace = StackTrace.current,
    );
    final processedEvent = sut.apply(event) as SentryEvent;

    expect(processedEvent.throwable, event.throwable);
    expect(processedEvent.request?.method, 'GET');
    expect(processedEvent.request?.queryString, 'foo=bar');
    expect(processedEvent.request?.data, null);
    expect(processedEvent.request?.headers, <String, String>{});
  });
}

final requestOptions = RequestOptions(
  path: '/foo/bar',
  baseUrl: 'https://example.org',
  queryParameters: <String, dynamic>{'foo': 'bar'},
  headers: <String, dynamic>{
    'foo': 'bar',
  },
  method: 'GET',
);

class Fixture {
  DioEventProcessor getSut({bool sendDefaultPii = false}) {
    return DioEventProcessor(
      SentryOptions(dsn: fakeDsn)..sendDefaultPii = sendDefaultPii,
      MaxRequestBodySize.always,
    );
  }
}
