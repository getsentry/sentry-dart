// ignore_for_file: deprecated_member_use

import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:sentry_dio/src/dio_error_extractor.dart';
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

    final throwable = Exception();
    final event = SentryEvent(
      throwable: Exception(),
      exceptions: [fixture.sentryError(throwable)],
    );
    final processedEvent = sut.apply(event, Hint()) as SentryEvent;

    expect(event, processedEvent);
  });

  test(
      '$DioEventProcessor does not change anything '
      'if stacktrace is null and a request is present', () {
    final sut = fixture.getSut();

    final dioError = DioError(
      requestOptions: RequestOptions(path: '/foo/bar'),
    );
    final event = SentryEvent(
      throwable: dioError,
      request: SentryRequest(),
      exceptions: [fixture.sentryError(dioError)],
    );
    final processedEvent = sut.apply(event, Hint()) as SentryEvent;

    expect(event.throwable, processedEvent.throwable);
    expect(event.request, processedEvent.request);
  });

  group('request', () {
    test('$DioEventProcessor adds request', () {
      final sut = fixture.getSut(sendDefaultPii: true);

      final request = requestOptions.copyWith(
        method: 'POST',
        data: 'foobar',
      );
      final throwable = Exception();
      final dioError = DioError(
        requestOptions: request,
        response: Response<dynamic>(
          requestOptions: request,
        ),
      );
      final event = SentryEvent(
        throwable: throwable,
        exceptions: [
          fixture.sentryError(throwable),
          fixture.sentryError(dioError),
        ],
      );
      final processedEvent = sut.apply(event, Hint()) as SentryEvent;

      expect(processedEvent.throwable, event.throwable);
      expect(processedEvent.request?.method, 'POST');
      expect(processedEvent.request?.queryString, 'foo=bar');
      expect(processedEvent.request?.headers, <String, String>{
        'foo': 'bar',
      });
      expect(processedEvent.request?.data, 'foobar');
    });

    test('$DioEventProcessor adds request without pii', () {
      final sut = fixture.getSut(sendDefaultPii: false);

      final throwable = Exception();
      final dioError = DioError(
        requestOptions: requestOptions,
        response: Response<dynamic>(
          requestOptions: requestOptions,
          data: 'foobar',
        ),
      );
      final event = SentryEvent(
        throwable: throwable,
        exceptions: [
          fixture.sentryError(throwable),
          fixture.sentryError(dioError),
        ],
      );
      final processedEvent = sut.apply(event, Hint()) as SentryEvent;

      expect(processedEvent.throwable, event.throwable);
      expect(processedEvent.request?.method, 'GET');
      expect(processedEvent.request?.queryString, 'foo=bar');
      expect(processedEvent.request?.data, null);
      expect(processedEvent.request?.headers, <String, String>{});
    });

    test('$DioEventProcessor removes auth headers', () {
      final sut = fixture.getSut(sendDefaultPii: false);

      final requestOptionsWithAuthHeaders = requestOptions.copyWith(
        headers: {'authorization': 'foo', 'Authorization': 'bar'},
      );
      final throwable = Exception();
      final dioError = DioError(
        requestOptions: requestOptionsWithAuthHeaders,
        response: Response<dynamic>(
          requestOptions: requestOptionsWithAuthHeaders,
        ),
      );
      final event = SentryEvent(
        throwable: throwable,
        exceptions: [
          fixture.sentryError(throwable),
          fixture.sentryError(dioError),
        ],
      );
      final processedEvent = sut.apply(event, Hint()) as SentryEvent;

      expect(processedEvent.request?.headers, <String, String>{});
    });

    test('request body is included according to $MaxResponseBodySize',
        () async {
      final scenarios = [
        // never
        MaxBodySizeTestConfig(MaxRequestBodySize.never, 0, false),
        MaxBodySizeTestConfig(MaxRequestBodySize.never, 4001, false),
        MaxBodySizeTestConfig(MaxRequestBodySize.never, 10001, false),
        // always
        MaxBodySizeTestConfig(MaxRequestBodySize.always, 0, true),
        MaxBodySizeTestConfig(MaxRequestBodySize.always, 4001, true),
        MaxBodySizeTestConfig(MaxRequestBodySize.always, 10001, true),
        // small
        MaxBodySizeTestConfig(MaxRequestBodySize.small, 0, true),
        MaxBodySizeTestConfig(MaxRequestBodySize.small, 4000, true),
        MaxBodySizeTestConfig(MaxRequestBodySize.small, 4001, false),
        // medium
        MaxBodySizeTestConfig(MaxRequestBodySize.medium, 0, true),
        MaxBodySizeTestConfig(MaxRequestBodySize.medium, 4001, true),
        MaxBodySizeTestConfig(MaxRequestBodySize.medium, 10000, true),
        MaxBodySizeTestConfig(MaxRequestBodySize.medium, 10001, false),
      ];

      for (final scenario in scenarios) {
        final sut = fixture.getSut(
          sendDefaultPii: true,
          captureFailedRequests: true,
          maxRequestBodySize: scenario.maxBodySize,
        );

        final data = List.generate(scenario.contentLength, (index) => 0);
        final request = requestOptions.copyWith(method: 'POST', data: data);
        final throwable = Exception();
        final dioError = DioError(
          requestOptions: request,
          response: Response<dynamic>(
            requestOptions: request,
            statusCode: 401,
            data: data,
          ),
        );
        final event = SentryEvent(
          throwable: throwable,
          exceptions: [
            fixture.sentryError(throwable),
            fixture.sentryError(dioError),
          ],
        );
        final processedEvent = sut.apply(event, Hint()) as SentryEvent;
        final capturedRequest = processedEvent.request;

        expect(capturedRequest, isNotNull);
        expect(
          capturedRequest?.data,
          scenario.shouldBeIncluded ? isNotNull : isNull,
        );
      }
    });
  });

  group('response', () {
    test('$DioEventProcessor adds response', () {
      final sut = fixture.getSut(sendDefaultPii: true);

      final request = requestOptions.copyWith(
        method: 'POST',
        responseType: ResponseType.plain,
      );
      final throwable = Exception();
      final dioError = DioError(
        requestOptions: request,
        response: Response<dynamic>(
          data: 'foobar',
          headers: Headers.fromMap(<String, List<String>>{
            'foo': ['bar'],
            'set-cookie': ['foo=bar'],
          }),
          requestOptions: request,
          isRedirect: true,
          statusCode: 200,
          statusMessage: 'OK',
        ),
      );
      final event = SentryEvent(
        throwable: throwable,
        exceptions: [
          fixture.sentryError(throwable),
          fixture.sentryError(dioError),
        ],
      );
      final processedEvent = sut.apply(event, Hint()) as SentryEvent;

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

    test('$DioEventProcessor adds response without PII', () {
      final sut = fixture.getSut(sendDefaultPii: false);

      final request = requestOptions.copyWith(
        method: 'POST',
        responseType: ResponseType.plain,
      );
      final throwable = Exception();
      final dioError = DioError(
        requestOptions: request,
        response: Response<dynamic>(
          data: 'foobar',
          headers: Headers.fromMap(<String, List<String>>{
            'foo': ['bar'],
          }),
          requestOptions: request,
          isRedirect: true,
          statusCode: 200,
          statusMessage: 'OK',
        ),
      );
      final event = SentryEvent(
        throwable: throwable,
        exceptions: [
          fixture.sentryError(throwable),
          fixture.sentryError(dioError),
        ],
      );
      final processedEvent = sut.apply(event, Hint()) as SentryEvent;

      expect(processedEvent.throwable, event.throwable);
      expect(processedEvent.contexts.response, isNotNull);
      expect(processedEvent.contexts.response?.bodySize, 6);
      expect(processedEvent.contexts.response?.statusCode, 200);
      expect(processedEvent.contexts.response?.headers, <String, String>{});
    });

    test('response body is included according to $MaxResponseBodySize',
        () async {
      final scenarios = [
        // never
        MaxBodySizeTestConfig(MaxResponseBodySize.never, 0, false),
        MaxBodySizeTestConfig(MaxResponseBodySize.never, 4001, false),
        MaxBodySizeTestConfig(MaxResponseBodySize.never, 10001, false),
        // always
        MaxBodySizeTestConfig(MaxResponseBodySize.always, 0, true),
        MaxBodySizeTestConfig(MaxResponseBodySize.always, 4001, true),
        MaxBodySizeTestConfig(MaxResponseBodySize.always, 10001, true),
        // small
        MaxBodySizeTestConfig(MaxResponseBodySize.small, 0, true),
        MaxBodySizeTestConfig(MaxResponseBodySize.small, 4000, true),
        MaxBodySizeTestConfig(MaxResponseBodySize.small, 4001, false),
        // medium
        MaxBodySizeTestConfig(MaxResponseBodySize.medium, 0, true),
        MaxBodySizeTestConfig(MaxResponseBodySize.medium, 4001, true),
        MaxBodySizeTestConfig(MaxResponseBodySize.medium, 10000, true),
        MaxBodySizeTestConfig(MaxResponseBodySize.medium, 10001, false),
      ];

      for (final scenario in scenarios) {
        final sut = fixture.getSut(
          sendDefaultPii: true,
          captureFailedRequests: true,
          maxResponseBodySize: scenario.maxBodySize,
        );

        final data = List.generate(scenario.contentLength, (index) => 0);
        final request = requestOptions.copyWith(
          method: 'POST',
          data: data,
          responseType: ResponseType.bytes,
        );
        final throwable = Exception();
        final dioError = DioError(
          requestOptions: request,
          response: Response<dynamic>(
            requestOptions: request,
            statusCode: 401,
            data: data,
          ),
        );
        final event = SentryEvent(
          throwable: throwable,
          exceptions: [
            fixture.sentryError(throwable),
            fixture.sentryError(dioError),
          ],
        );
        final processedEvent = sut.apply(event, Hint()) as SentryEvent;
        final capturedResponse = processedEvent.contexts.response;

        expect(capturedResponse, isNotNull);
        expect(
          capturedResponse?.data,
          scenario.shouldBeIncluded ? isNotNull : isNull,
        );
      }
    });

    test('data supports all response body types', () async {
      final dataByType = {
        ResponseType.plain: ['plain'],
        ResponseType.bytes: [
          [1337],
        ],
        ResponseType.json: [
          9001,
          null,
          'string',
          true,
          ['list'],
          {'map-key': 'map-value'},
        ],
      };

      for (final entry in dataByType.entries) {
        final responseType = entry.key;

        for (final data in entry.value) {
          final request = requestOptions.copyWith(
            method: 'POST',
            data: data,
            responseType: responseType,
          );
          final throwable = Exception();
          final dioError = DioError(
            requestOptions: request,
            response: Response<dynamic>(
              requestOptions: request,
              statusCode: 401,
              data: data,
            ),
          );

          final sut = fixture.getSut(sendDefaultPii: true);

          final event = SentryEvent(
            throwable: throwable,
            exceptions: [
              fixture.sentryError(throwable),
              fixture.sentryError(dioError),
            ],
          );
          final processedEvent = sut.apply(event, Hint()) as SentryEvent;
          final capturedResponse = processedEvent.contexts.response;

          expect(capturedResponse, isNotNull);
          expect(capturedResponse?.data, data);
        }
      }
    });
  });

  test('$DioEventProcessor adds chained stacktraces', () {
    fixture.options.addExceptionCauseExtractor(DioErrorExtractor());

    final sut = fixture.getSut(sendDefaultPii: false);
    final exception = Exception('foo bar');
    final dioError = DioError(
      error: exception,
      requestOptions: requestOptions,
      stackTrace: StackTrace.current,
    );

    final extracted =
        fixture.exceptionFactory.extractor.flatten(dioError, null);
    final exceptions = extracted.map((element) {
      return fixture.exceptionFactory.getSentryException(
        element.exception,
        stackTrace: element.stackTrace,
      );
    }).toList();

    final event = SentryEvent(
      throwable: dioError,
      exceptions: exceptions,
    );

    final processedEvent = sut.apply(event, Hint()) as SentryEvent;

    expect(processedEvent.exceptions?.length, 2);

    expect(processedEvent.exceptions?[0].value, dioError.toString());
    expect(processedEvent.exceptions?[0].stackTrace, isNotNull);

    expect(processedEvent.exceptions?[1].value, exception.toString());
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
  final SentryOptions options = defaultTestOptions();

  // ignore: invalid_use_of_internal_member
  SentryExceptionFactory get exceptionFactory => options.exceptionFactory;

  DioEventProcessor getSut({
    bool sendDefaultPii = false,
    bool captureFailedRequests = true,
    MaxRequestBodySize maxRequestBodySize = MaxRequestBodySize.always,
    MaxResponseBodySize maxResponseBodySize = MaxResponseBodySize.always,
  }) {
    return DioEventProcessor(
      options
        ..sendDefaultPii = sendDefaultPii
        ..captureFailedRequests = captureFailedRequests
        ..maxRequestBodySize = maxRequestBodySize
        ..maxResponseBodySize = maxResponseBodySize,
    );
  }

  SentryException sentryError(dynamic throwable) {
    return SentryException(
      type: throwable.runtimeType.toString(),
      value: throwable.toString(),
      throwable: throwable,
    );
  }
}

class MaxBodySizeTestConfig<T> {
  MaxBodySizeTestConfig(
    this.maxBodySize,
    this.contentLength,
    this.shouldBeIncluded,
  );

  final T maxBodySize;
  final int contentLength;
  final bool shouldBeIncluded;

  Matcher get matcher => shouldBeIncluded ? isNotNull : isNull;
}
