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

    test('$DioEventProcessor adds request/response without pii', () {
      final sut = fixture.getSut(sendDefaultPii: false);

      // Create a request with headers to verify they get filtered out
      final requestWithHeaders = requestOptions.copyWith(
        headers: {
          'content-type': 'application/json',
          'user-agent': 'test-agent',
          'x-custom-header': 'custom-value',
        },
      );

      final throwable = Exception();
      final dioError = DioError(
        requestOptions: requestWithHeaders,
        response: Response<dynamic>(
          requestOptions: requestWithHeaders,
          data: 'foobar',
          headers: Headers.fromMap(<String, List<String>>{
            'content-type': ['application/json'],
            'server': ['test-server'],
            'x-response-header': ['response-value'],
          }),
        ),
      );
      final event = SentryEvent(
        throwable: throwable,
        exceptions: [
          fixture.sentryError(throwable),
          fixture.sentryError(dioError),
        ],
      );
      final hint = Hint();
      final processedEvent = sut.apply(event, hint) as SentryEvent;

      // Verify processed request has empty headers (filtered out due to sendDefaultPii: false)
      expect(processedEvent.throwable, event.throwable);
      expect(processedEvent.request?.method, 'GET');
      expect(processedEvent.request?.queryString, 'foo=bar');
      expect(processedEvent.request?.data, null);
      expect(processedEvent.request?.headers, <String, String>{});

      // Verify response headers are also empty (filtered out due to sendDefaultPii: false)
      final capturedResponse = hint.response;
      expect(capturedResponse?.headers, <String, String>{});
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

    test('request body is included according to $MaxRequestBodySize', () async {
      final scenarios = [
        // never
        MaxRequestBodySizeTestConfig(MaxRequestBodySize.never, 0, false),
        MaxRequestBodySizeTestConfig(MaxRequestBodySize.never, 4001, false),
        MaxRequestBodySizeTestConfig(MaxRequestBodySize.never, 10001, false),
        // always
        MaxRequestBodySizeTestConfig(MaxRequestBodySize.always, 0, true),
        MaxRequestBodySizeTestConfig(MaxRequestBodySize.always, 4001, true),
        MaxRequestBodySizeTestConfig(MaxRequestBodySize.always, 10001, true),
        // small
        MaxRequestBodySizeTestConfig(MaxRequestBodySize.small, 0, true),
        MaxRequestBodySizeTestConfig(MaxRequestBodySize.small, 4000, true),
        MaxRequestBodySizeTestConfig(MaxRequestBodySize.small, 4001, false),
        // medium
        MaxRequestBodySizeTestConfig(MaxRequestBodySize.medium, 0, true),
        MaxRequestBodySizeTestConfig(MaxRequestBodySize.medium, 4001, true),
        MaxRequestBodySizeTestConfig(MaxRequestBodySize.medium, 10000, true),
        MaxRequestBodySizeTestConfig(MaxRequestBodySize.medium, 10001, false),
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

  group('request data types', () {
    test('handles String data correctly', () {
      final sut = fixture.getSut(sendDefaultPii: true);

      final data = 'Hello, World!';
      final request = requestOptions.copyWith(
        method: 'POST',
        data: data,
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

      expect(processedEvent.request?.data, data);
    });

    test('handles json map data correctly', () {
      final sut = fixture.getSut(sendDefaultPii: true);

      final data = {'key1': 'value1', 'key2': 42, 'key3': true};
      final request = requestOptions.copyWith(
        method: 'POST',
        data: data,
        contentType: 'application/json',
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

      expect(processedEvent.request?.data, data);
    });

    test('handles json list data correctly', () {
      final sut = fixture.getSut(sendDefaultPii: true);

      final data = ['item1', 'item2', 123, false];
      final request = requestOptions.copyWith(
        method: 'POST',
        data: data,
        contentType: 'application/json',
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

      expect(processedEvent.request?.data, data);
    });

    test('handles FormData correctly', () {
      final sut = fixture.getSut(sendDefaultPii: true);

      final formData = FormData.fromMap({
        'field1': 'value1',
        'field2': 'value2',
      });
      final request = requestOptions.copyWith(
        method: 'POST',
        data: formData,
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

      expect(processedEvent.request?.data, isNotNull);
      expect(processedEvent.request?.data, isA<Map<dynamic, dynamic>>());
      final capturedData = processedEvent.request?.data as Map;
      expect(capturedData['field1'], 'value1');
      expect(capturedData['field2'], 'value2');
    });

    test('handles FormData with files correctly', () {
      final sut = fixture.getSut(sendDefaultPii: true);

      final formData = FormData.fromMap({
        'field1': 'value1',
      });
      // Add a file to FormData
      formData.files.add(
        MapEntry(
          'file1',
          MultipartFile.fromString(
            'file content',
            filename: 'test.txt',
          ),
        ),
      );

      final request = requestOptions.copyWith(
        method: 'POST',
        data: formData,
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

      expect(processedEvent.request?.data, isNotNull);
      expect(processedEvent.request?.data, isA<Map<dynamic, dynamic>>());
      final capturedData = processedEvent.request?.data as Map;
      expect(capturedData['field1'], 'value1');
      expect(capturedData['file1_file'], isA<Map<dynamic, dynamic>>());
      final fileData = capturedData['file1_file'] as Map;
      expect(fileData['filename'], 'test.txt');
      expect(fileData['length'], greaterThan(0));
    });

    test('handles MultipartFile correctly', () {
      final sut = fixture.getSut(sendDefaultPii: true);

      final file = MultipartFile.fromString(
        'file content here',
        filename: 'test.txt',
        contentType: DioMediaType('text', 'plain'),
        headers: {
          'custom-header': ['custom-value'],
          'x-file-id': ['12345'],
        },
      );
      final request = requestOptions.copyWith(
        method: 'POST',
        data: file,
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

      expect(processedEvent.request?.data, isNotNull);
      expect(processedEvent.request?.data, isA<Map<dynamic, dynamic>>());
      final capturedData = processedEvent.request?.data as Map;
      expect(capturedData['filename'], 'test.txt');
      expect(capturedData['length'], greaterThan(0));
      expect(capturedData['contentType'], contains('text/plain'));

      // Test headers
      expect(capturedData['headers'], isA<Map<dynamic, dynamic>>());
      final headers = capturedData['headers'] as Map;
      expect(headers['custom-header'], ['custom-value']);
      expect(headers['x-file-id'], ['12345']);
    });

    test('handles primitive types correctly', () {
      final sut = fixture.getSut(sendDefaultPii: true);

      // Test num
      final numData = 42;
      final numRequest = requestOptions.copyWith(
        method: 'POST',
        data: numData,
      );
      final numEvent = SentryEvent(
        throwable: Exception(),
        exceptions: [
          fixture.sentryError(Exception()),
          fixture.sentryError(DioError(requestOptions: numRequest)),
        ],
      );
      final processedNumEvent = sut.apply(numEvent, Hint()) as SentryEvent;
      expect(processedNumEvent.request?.data, numData);

      // Test bool
      final boolData = true;
      final boolRequest = requestOptions.copyWith(
        method: 'POST',
        data: boolData,
      );
      final boolEvent = SentryEvent(
        throwable: Exception(),
        exceptions: [
          fixture.sentryError(Exception()),
          fixture.sentryError(DioError(requestOptions: boolRequest)),
        ],
      );
      final processedBoolEvent = sut.apply(boolEvent, Hint()) as SentryEvent;
      expect(processedBoolEvent.request?.data, boolData);
    });
  });

  group('maxRequestBodySize', () {
    test('respects maxRequestBodySize.never for primitive types', () {
      final sut = fixture.getSut(
        sendDefaultPii: true,
        maxRequestBodySize: MaxRequestBodySize.never,
      );

      // Test num - should not be added when maxRequestBodySize is never
      final numData = 42;
      final numRequest = requestOptions.copyWith(method: 'POST', data: numData);
      final numEvent = SentryEvent(
        throwable: Exception(),
        exceptions: [
          fixture.sentryError(Exception()),
          fixture.sentryError(DioError(requestOptions: numRequest)),
        ],
      );
      final processedNumEvent = sut.apply(numEvent, Hint()) as SentryEvent;
      expect(processedNumEvent.request?.data, isNull);

      // Test bool - should not be added when maxRequestBodySize is never
      final boolData = true;
      final boolRequest =
          requestOptions.copyWith(method: 'POST', data: boolData);
      final boolEvent = SentryEvent(
        throwable: Exception(),
        exceptions: [
          fixture.sentryError(Exception()),
          fixture.sentryError(DioError(requestOptions: boolRequest)),
        ],
      );
      final processedBoolEvent = sut.apply(boolEvent, Hint()) as SentryEvent;
      expect(processedBoolEvent.request?.data, isNull);
    });

    test('respects maxRequestBodySize.small for large String data', () {
      final sut = fixture.getSut(
        sendDefaultPii: true,
        maxRequestBodySize: MaxRequestBodySize.small,
      );

      // Test String - should not be added due to size (4000 bytes = 4000 characters)
      final largeString = 'x' * 5000; // 5000 characters > 4000 limit
      final stringRequest =
          requestOptions.copyWith(method: 'POST', data: largeString);
      final stringEvent = SentryEvent(
        throwable: Exception(),
        exceptions: [
          fixture.sentryError(Exception()),
          fixture.sentryError(DioError(requestOptions: stringRequest)),
        ],
      );
      final processedStringEvent =
          sut.apply(stringEvent, Hint()) as SentryEvent;
      expect(processedStringEvent.request?.data, isNull);
    });

    test('respects maxRequestBodySize.small for large List<int> data', () {
      final sut = fixture.getSut(
        sendDefaultPii: true,
        maxRequestBodySize: MaxRequestBodySize.small,
      );

      // Test List<int> - should not be added due to size
      final largeList = List<int>.filled(5000, 1); // 5000 bytes > 4000 limit
      final listRequest =
          requestOptions.copyWith(method: 'POST', data: largeList);
      final listEvent = SentryEvent(
        throwable: Exception(),
        exceptions: [
          fixture.sentryError(Exception()),
          fixture.sentryError(DioError(requestOptions: listRequest)),
        ],
      );
      final processedListEvent = sut.apply(listEvent, Hint()) as SentryEvent;
      expect(processedListEvent.request?.data, isNull);
    });

    test('respects maxRequestBodySize.small for large Map data', () {
      final sut = fixture.getSut(
        sendDefaultPii: true,
        maxRequestBodySize: MaxRequestBodySize.small,
      );

      // Test Map - should not be added due to size
      final largeMap = <String, String>{};
      for (int i = 0; i < 200; i++) {
        largeMap['key$i'] =
            'value' * 25; // Each value is 125 characters, total > 4000
      }
      final mapRequest = requestOptions.copyWith(
        method: 'POST',
        data: largeMap,
        contentType: 'application/json',
      );
      final mapEvent = SentryEvent(
        throwable: Exception(),
        exceptions: [
          fixture.sentryError(Exception()),
          fixture.sentryError(DioError(requestOptions: mapRequest)),
        ],
      );
      final processedMapEvent = sut.apply(mapEvent, Hint()) as SentryEvent;
      expect(processedMapEvent.request?.data, isNull);
    });

    test('respects maxRequestBodySize.small for large List data', () {
      final sut = fixture.getSut(
        sendDefaultPii: true,
        maxRequestBodySize: MaxRequestBodySize.small,
      );

      // Test List - should not be added due to size
      final largeListData = List<String>.generate(
        200,
        (i) => 'item$i' * 25,
      ); // Each item is 125+ characters, total > 4000
      final largeListRequest = requestOptions.copyWith(
        method: 'POST',
        data: largeListData,
        contentType: 'application/json',
      );
      final largeListEvent = SentryEvent(
        throwable: Exception(),
        exceptions: [
          fixture.sentryError(Exception()),
          fixture.sentryError(DioError(requestOptions: largeListRequest)),
        ],
      );
      final processedLargeListEvent =
          sut.apply(largeListEvent, Hint()) as SentryEvent;
      expect(processedLargeListEvent.request?.data, isNull);
    });

    test('respects maxRequestBodySize.small for large FormData', () {
      final sut = fixture.getSut(
        sendDefaultPii: true,
        maxRequestBodySize: MaxRequestBodySize.small,
      );

      // Test FormData - should not be added due to size
      final largeFormData = FormData.fromMap({});
      for (int i = 0; i < 200; i++) {
        largeFormData.fields.add(
          MapEntry(
            'field$i',
            'value' * 25,
          ),
        ); // Each field value is 125 characters, total > 4000
      }
      final formDataRequest =
          requestOptions.copyWith(method: 'POST', data: largeFormData);
      final formDataEvent = SentryEvent(
        throwable: Exception(),
        exceptions: [
          fixture.sentryError(Exception()),
          fixture.sentryError(DioError(requestOptions: formDataRequest)),
        ],
      );
      final processedFormDataEvent =
          sut.apply(formDataEvent, Hint()) as SentryEvent;
      expect(processedFormDataEvent.request?.data, isNull);
    });

    test('respects maxRequestBodySize.small for large MultipartFile', () {
      final sut = fixture.getSut(
        sendDefaultPii: true,
        maxRequestBodySize: MaxRequestBodySize.small,
      );

      // Test MultipartFile - should not be added due to size
      final largeFile = MultipartFile.fromString(
        'x' * 5000,
        filename: 'large.txt',
      ); // 5000 characters > 4000 limit
      final fileRequest =
          requestOptions.copyWith(method: 'POST', data: largeFile);
      final fileEvent = SentryEvent(
        throwable: Exception(),
        exceptions: [
          fixture.sentryError(Exception()),
          fixture.sentryError(DioError(requestOptions: fileRequest)),
        ],
      );
      final processedFileEvent = sut.apply(fileEvent, Hint()) as SentryEvent;
      expect(processedFileEvent.request?.data, isNull);
    });

    test('adds small JSON data when within size limit', () {
      final sut = fixture.getSut(
        sendDefaultPii: true,
        maxRequestBodySize: MaxRequestBodySize.small,
      );

      // Small JSON object - should be added
      final smallJsonData = <String, dynamic>{
        'name': 'John Doe',
        'age': 30,
        'city': 'New York',
      };
      final smallJsonRequest = requestOptions.copyWith(
        method: 'POST',
        data: smallJsonData,
        contentType: 'application/json',
      );
      final smallJsonEvent = SentryEvent(
        throwable: Exception(),
        exceptions: [
          fixture.sentryError(Exception()),
          fixture.sentryError(DioError(requestOptions: smallJsonRequest)),
        ],
      );
      final processedSmallJsonEvent =
          sut.apply(smallJsonEvent, Hint()) as SentryEvent;
      expect(processedSmallJsonEvent.request?.data, equals(smallJsonData));
    });

    test('rejects large JSON data when exceeding size limit', () {
      final sut = fixture.getSut(
        sendDefaultPii: true,
        maxRequestBodySize: MaxRequestBodySize.small,
      );

      // Large JSON object - should not be added due to size
      final largeJsonData = <String, dynamic>{
        'users': List.generate(
          100,
          (i) => {
            'id': i,
            'name': 'User $i',
            'email': 'user$i@example.com',
            'description':
                'This is a very long description for user $i that will make the JSON exceed the size limit',
          },
        ),
      };
      final largeJsonRequest = requestOptions.copyWith(
        method: 'POST',
        data: largeJsonData,
        contentType: 'application/json',
      );
      final largeJsonEvent = SentryEvent(
        throwable: Exception(),
        exceptions: [
          fixture.sentryError(Exception()),
          fixture.sentryError(DioError(requestOptions: largeJsonRequest)),
        ],
      );
      final processedLargeJsonEvent =
          sut.apply(largeJsonEvent, Hint()) as SentryEvent;
      expect(processedLargeJsonEvent.request?.data, isNull);
    });

    test('handles JSON encoding errors gracefully', () {
      final sut = fixture.getSut(
        sendDefaultPii: true,
        maxRequestBodySize: MaxRequestBodySize.medium,
      );

      // Test circular reference - should not be added due to encoding error
      final circularData = <String, dynamic>{};
      circularData['self'] = circularData; // Creates circular reference

      final circularRequest = requestOptions.copyWith(
        method: 'POST',
        data: circularData,
        contentType: 'application/json',
      );
      final circularEvent = SentryEvent(
        throwable: Exception(),
        exceptions: [
          fixture.sentryError(Exception()),
          fixture.sentryError(DioError(requestOptions: circularRequest)),
        ],
      );
      final processedCircularEvent =
          sut.apply(circularEvent, Hint()) as SentryEvent;
      expect(processedCircularEvent.request?.data, isNull);

      // Test data with infinity - should not be added due to encoding error
      final infinityData = <String, dynamic>{
        'value': double.infinity,
        'name': 'test',
      };

      final infinityRequest = requestOptions.copyWith(
        method: 'POST',
        data: infinityData,
        contentType: 'application/json',
      );
      final infinityEvent = SentryEvent(
        throwable: Exception(),
        exceptions: [
          fixture.sentryError(Exception()),
          fixture.sentryError(DioError(requestOptions: infinityRequest)),
        ],
      );
      final processedInfinityEvent =
          sut.apply(infinityEvent, Hint()) as SentryEvent;
      expect(processedInfinityEvent.request?.data, isNull);
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
            'content-length': ['6'],
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
      final hint = Hint();
      final processedEvent = sut.apply(event, hint) as SentryEvent;
      final capturedResponse = hint.response;

      expect(processedEvent.throwable, event.throwable);
      expect(capturedResponse, isNotNull);
      expect(capturedResponse?.bodySize, 6);
      expect(capturedResponse?.statusCode, 200);
      expect(capturedResponse?.headers, {
        'foo': 'bar',
        'set-cookie': 'foo=bar',
        'content-length': '6',
      });
      expect(capturedResponse?.cookies, 'foo=bar');
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
            'content-length': ['6'],
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

      final hint = Hint();
      sut.apply(event, hint) as SentryEvent;
      final capturedResponse = hint.response;

      expect(processedEvent.throwable, event.throwable);
      expect(capturedResponse, isNotNull);
      expect(capturedResponse?.bodySize, 6);
      expect(capturedResponse?.statusCode, 200);
      expect(capturedResponse?.headers, <String, String>{});
    });

    test('response body is included if smaller 0.15mb', () async {
      final scenarios = [
        // Headers with content-length
        MaxResponseBodySizeTestConfig(0, true, true),
        MaxResponseBodySizeTestConfig(4001, true, true),
        MaxResponseBodySizeTestConfig(10001, true, true),
        MaxResponseBodySizeTestConfig(157287, true, false),
        // // Headers without content-length
        MaxResponseBodySizeTestConfig(0, false, false),
        MaxResponseBodySizeTestConfig(4001, false, false),
        MaxResponseBodySizeTestConfig(10001, false, false),
        MaxResponseBodySizeTestConfig(157287, false, false),
      ];

      for (final scenario in scenarios) {
        final sut = fixture.getSut(
          sendDefaultPii: true,
          captureFailedRequests: true,
        );

        final data = List.generate(scenario.contentLength, (index) => 0);
        final request = requestOptions.copyWith(
          method: 'POST',
          data: data,
          responseType: ResponseType.bytes,
        );
        final throwable = Exception();
        final headers = {
          'content-length': ['${scenario.contentLength}'],
        };

        final dioError = DioError(
          requestOptions: request,
          response: Response<dynamic>(
            requestOptions: request,
            statusCode: 401,
            data: data,
            headers: scenario.headersHaveContentLength
                ? Headers.fromMap(headers)
                : null,
          ),
        );
        final event = SentryEvent(
          throwable: throwable,
          exceptions: [
            fixture.sentryError(throwable),
            fixture.sentryError(dioError),
          ],
        );
        final hint = Hint();
        sut.apply(event, hint) as SentryEvent;
        final capturedResponse = hint.response;

        expect(capturedResponse, isNotNull);
        expect(
          capturedResponse?.bodySize,
          scenario.headersHaveContentLength ? scenario.contentLength : isNull,
        );
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
          final headers = {
            'content-length': [
              '9001',
            ], // Dummy content size, not relevant for this test
          };
          final dioError = DioError(
            requestOptions: request,
            response: Response<dynamic>(
              requestOptions: request,
              statusCode: 401,
              data: data,
              headers: Headers.fromMap(headers),
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
          final hint = Hint();
          sut.apply(event, hint) as SentryEvent;
          final capturedResponse = hint.response;

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
  }) {
    return DioEventProcessor(
      options
        ..sendDefaultPii = sendDefaultPii
        ..captureFailedRequests = captureFailedRequests
        ..maxRequestBodySize = maxRequestBodySize,
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

class MaxRequestBodySizeTestConfig<T> {
  MaxRequestBodySizeTestConfig(
    this.maxBodySize,
    this.contentLength,
    this.shouldBeIncluded,
  );

  final T maxBodySize;
  final int contentLength;
  final bool shouldBeIncluded;

  Matcher get matcher => shouldBeIncluded ? isNotNull : isNull;
}

class MaxResponseBodySizeTestConfig {
  MaxResponseBodySizeTestConfig(
    this.contentLength,
    this.headersHaveContentLength,
    this.shouldBeIncluded,
  );

  final int contentLength;
  final bool headersHaveContentLength;
  final bool shouldBeIncluded;

  Matcher get matcher => shouldBeIncluded ? isNotNull : isNull;
}
