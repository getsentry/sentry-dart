import 'package:diox/diox.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_diox/sentry_dio.dart';
import 'package:test/test.dart';
import 'package:sentry/src/sentry_exception_factory.dart';

import 'mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('$DioxEventProcessor only processes ${DioError}s', () {
    final sut = fixture.getSut();

    final event = SentryEvent(throwable: Exception());
    final processedEvent = sut.apply(event) as SentryEvent;

    expect(event, processedEvent);
  });

  test(
      '$DioxEventProcessor does not change anything '
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

  group('request', () {
    test('$DioxEventProcessor adds request', () {
      final sut = fixture.getSut(sendDefaultPii: true);

      final request = requestOptions.copyWith(
        method: 'POST',
        data: 'foobar',
      );
      final event = SentryEvent(
        throwable: DioError(
          requestOptions: request,
          response: Response<dynamic>(
            requestOptions: request,
          ),
        ),
      );
      final processedEvent = sut.apply(event) as SentryEvent;

      expect(processedEvent.throwable, event.throwable);
      expect(processedEvent.request?.method, 'POST');
      expect(processedEvent.request?.queryString, 'foo=bar');
      expect(processedEvent.request?.headers, <String, String>{'foo': 'bar'});
      expect(processedEvent.request?.data, 'foobar');
    });

    test('$DioxEventProcessor adds request without pii', () {
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
  });

  group('response', () {
    test('$DioxEventProcessor adds response', () {
      final sut = fixture.getSut(sendDefaultPii: true);

      final request = requestOptions.copyWith(
        method: 'POST',
      );
      final event = SentryEvent(
        throwable: DioError(
          requestOptions: request,
          response: Response<dynamic>(
            data: 'foobar',
            headers: Headers.fromMap(<String, List<String>>{
              'foo': ['bar'],
              'set-cookie': ['foo=bar']
            }),
            requestOptions: request,
            isRedirect: true,
            statusCode: 200,
            statusMessage: 'OK',
          ),
        ),
      );
      final processedEvent = sut.apply(event) as SentryEvent;

      expect(processedEvent.throwable, event.throwable);
      expect(processedEvent.contexts.response, isNotNull);
      expect(processedEvent.contexts.response?.bodySize, 6);
      expect(processedEvent.contexts.response?.statusCode, 200);
      expect(processedEvent.contexts.response?.headers, {
        'foo': 'bar',
        'set-cookie': 'foo=bar',
      });
      expect(processedEvent.contexts.response?.cookies, 'foo=bar');
    });

    test('$DioxEventProcessor adds response without PII', () {
      final sut = fixture.getSut(sendDefaultPii: false);

      final request = requestOptions.copyWith(
        method: 'POST',
      );
      final event = SentryEvent(
        throwable: DioError(
          requestOptions: request,
          response: Response<dynamic>(
            data: 'foobar',
            headers: Headers.fromMap(<String, List<String>>{
              'foo': ['bar']
            }),
            requestOptions: request,
            isRedirect: true,
            statusCode: 200,
            statusMessage: 'OK',
          ),
        ),
      );
      final processedEvent = sut.apply(event) as SentryEvent;

      expect(processedEvent.throwable, event.throwable);
      expect(processedEvent.contexts.response, isNotNull);
      expect(processedEvent.contexts.response?.bodySize, 6);
      expect(processedEvent.contexts.response?.statusCode, 200);
      expect(processedEvent.contexts.response?.headers, <String, String>{});
    });
  });

  test('$DioxEventProcessor adds chained stacktraces', () {
    final sut = fixture.getSut(sendDefaultPii: false);
    final exception = Exception('foo bar');
    final dioError = DioError(
      error: exception,
      requestOptions: requestOptions,
      stackTrace: StackTrace.current,
    );

    final event = SentryEvent(
      throwable: dioError,
      exceptions: [fixture.exceptionFactory.getSentryException(dioError)],
    );

    final processedEvent = sut.apply(event) as SentryEvent;

    final effectiveDioError = DioError(
      requestOptions: dioError.requestOptions,
      response: dioError.response,
      type: dioError.type,
      error: null,
      stackTrace: null,
      message: dioError.message,
    );

    expect(processedEvent.exceptions?.length, 2);
    expect(processedEvent.exceptions?[0].value, exception.toString());
    expect(processedEvent.exceptions?[0].stackTrace, isNotNull);
    expect(processedEvent.exceptions?[1].value, effectiveDioError.toString());
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

  DioxEventProcessor getSut({bool sendDefaultPii = false}) {
    return DioxEventProcessor(
      options..sendDefaultPii = sendDefaultPii,
      MaxRequestBodySize.always,
      MaxResponseBodySize.always,
    );
  }
}
