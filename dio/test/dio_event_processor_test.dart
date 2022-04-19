import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:test/test.dart';
import 'package:sentry/src/sentry_exception_factory.dart';

import 'mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('$DioEventProcessor only processes ${DioError}s', () {
    final sut = fixture.getSut();

    final event = SentryEvent(throwable: Exception());
    final processedEvent = sut.apply(event) as SentryEvent;

    expect(event, processedEvent);
  });

  test(
      '$DioEventProcessor does not change anything '
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

  test('$DioEventProcessor adds request', () {
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

  test('$DioEventProcessor adds request without pii', () {
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

  test('$DioEventProcessor adds request without pii', () {
    final sut = fixture.getSut(sendDefaultPii: false);
    final dioError = DioError(
      error: Exception('foo bar'),
      requestOptions: requestOptions,
      response: Response<dynamic>(
        requestOptions: requestOptions,
        data: 'foobar',
      ),
    );

    final event = SentryEvent(throwable: dioError);

    final processedEvent = sut.apply(event) as SentryEvent;

    expect(processedEvent.throwable, event.throwable);
    expect(processedEvent.request?.method, 'GET');
    expect(processedEvent.request?.queryString, 'foo=bar');
    expect(processedEvent.request?.data, null);
    expect(processedEvent.request?.headers, <String, String>{});
  });

  test('$DioEventProcessor adds chained stacktraces', () {
    final sut = fixture.getSut(sendDefaultPii: false);
    final exception = Exception('foo bar');
    final dioError = DioError(
      error: exception,
      requestOptions: requestOptions,
    )..stackTrace = StackTrace.current;

    final event = SentryEvent(
      throwable: dioError,
      exceptions: [fixture.exceptionFactory.getSentryException(dioError)],
    );

    final processedEvent = sut.apply(event) as SentryEvent;

    expect(processedEvent.exceptions?.length, 2);
    expect(processedEvent.exceptions?[0].value, exception.toString());
    expect(processedEvent.exceptions?[0].stackTrace, isNotNull);
    expect(
      processedEvent.exceptions?[1].value,
      (dioError..stackTrace = null).toString(),
    );
    expect(processedEvent.exceptions?[1].stackTrace, isNotNull);
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
  final SentryOptions options = SentryOptions(dsn: fakeDsn);

  // ignore: invalid_use_of_internal_member
  SentryExceptionFactory get exceptionFactory => options.exceptionFactory;

  DioEventProcessor getSut({bool sendDefaultPii = false}) {
    return DioEventProcessor(
      options..sendDefaultPii = sendDefaultPii,
      MaxRequestBodySize.always,
    );
  }
}
