import 'package:dio/dio.dart';
import 'package:http/http.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/http_client/failed_request_client.dart';
import 'package:sentry_dio/src/failed_request_client_adapter.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_http_client_adapter.dart';
import 'mocks/mock_hub.dart';
import 'mocks/mock_transport.dart';

final requestUri = Uri.parse('https://example.com?foo=bar');
final requestOptions = '?foo=bar';

void main() {
  group(FailedRequestClientAdapter, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('no captured events when everything goes well', () async {
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
      );

      final response = await sut.get<dynamic>(requestOptions);
      expect(response.statusCode, 200);

      expect(fixture.transport.calls, 0);
    });

    test('exception gets reported if client throws', () async {
      final sut = fixture.getSut(
        client: createThrowingClient(),
        captureFailedRequests: true,
      );

      await expectLater(
        () async => await sut.get<dynamic>(
          requestOptions,
          options: Options(headers: <String, String>{'Cookie': 'foo=bar'}),
        ),
        throwsException,
      );

      expect(fixture.transport.calls, 1);

      final eventCall = fixture.transport.events.first;
      final exception = eventCall.exceptions?.first;
      final mechanism = exception?.mechanism;

      expect(exception?.stackTrace, isNotNull);
      expect(mechanism?.type, 'SentryHttpClient');

      final request = eventCall.request;
      expect(request, isNotNull);
      expect(request?.method, 'GET');
      expect(request?.url, 'https://example.com?');
      expect(request?.queryString, 'foo=bar');
      expect(request?.cookies, 'foo=bar');
      expect(request?.headers, {'Cookie': 'foo=bar'});
      expect(request?.other.keys.contains('duration'), true);
      expect(request?.other.keys.contains('content_length'), false);
    });

    test('exception gets not reported if disabled', () async {
      final sut = fixture.getSut(
        client: createThrowingClient(),
        captureFailedRequests: false,
      );

      await expectLater(
        () async => await sut.get<dynamic>(
          requestOptions,
          options: Options(headers: <String, String>{'Cookie': 'foo=bar'}),
        ),
        throwsException,
      );

      expect(fixture.transport.calls, 0);
    });

    test('exception gets reported if bad status code occurs', () async {
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 404, reason: 'Not Found'),
        badStatusCodes: [SentryStatusCode(404)],
      );

      try {
        await sut.get<dynamic>(
          requestOptions,
          options: Options(headers: <String, String>{'Cookie': 'foo=bar'}),
        );
      } on DioError catch (_) {
        // a 404 throws an exception with dio
      }

      expect(fixture.transport.calls, 1);

      final eventCall = fixture.transport.events.first;
      final exception = eventCall.exceptions?.first;
      final mechanism = exception?.mechanism;

      expect(mechanism?.type, 'SentryHttpClient');
      expect(
        mechanism?.description,
        'Event was captured because the request status code was 404',
      );

      expect(exception?.type, 'SentryHttpClientError');
      expect(
        exception?.value,
        'Exception: Event was captured because the request status code was 404',
      );

      final request = eventCall.request;
      expect(request, isNotNull);
      expect(request?.method, 'GET');
      expect(request?.url, 'https://example.com?');
      expect(request?.queryString, 'foo=bar');
      expect(request?.cookies, 'foo=bar');
      expect(request?.headers, {'Cookie': 'foo=bar'});
      expect(request?.other.keys.contains('duration'), true);
      expect(request?.other.keys.contains('content_length'), false);
    });

    test(
        'just one report on status code reporting with failing requests enabled',
        () async {
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 404, reason: 'Not Found'),
        badStatusCodes: [SentryStatusCode(404)],
        captureFailedRequests: true,
      );

      try {
        await sut.get<dynamic>(
          requestOptions,
          options: Options(headers: <String, String>{'Cookie': 'foo=bar'}),
        );
      } on DioError catch (_) {
        // dio throws on 404
      }

      expect(fixture.transport.calls, 1);
    });

    test('close does get called for user defined client', () async {
      final mockHub = MockHub();

      final mockClient = CloseableMockClient();

      final client = FailedRequestClient(client: mockClient, hub: mockHub);
      client.close();

      expect(mockHub.addBreadcrumbCalls.length, 0);
      expect(mockHub.captureExceptionCalls.length, 0);
      verify(mockClient.close());
    });

    test('pii is not send on exception', () async {
      final sut = fixture.getSut(
        client: createThrowingClient(),
        captureFailedRequests: true,
        sendDefaultPii: false,
      );

      await expectLater(
        () async => await sut.get<dynamic>(
          requestOptions,
          options: Options(headers: <String, String>{'Cookie': 'foo=bar'}),
        ),
        throwsException,
      );

      final event = fixture.transport.events.first;
      expect(fixture.transport.calls, 1);
      expect(event.request?.headers.isEmpty, true);
      expect(event.request?.cookies, isNull);
    });

    test('pii is not send on invalid status code', () async {
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 404, reason: 'Not Found'),
        badStatusCodes: [SentryStatusCode(404)],
        captureFailedRequests: false,
        sendDefaultPii: false,
      );

      try {
        await sut.get<dynamic>(
          requestOptions,
          options: Options(headers: <String, String>{'Cookie': 'foo=bar'}),
        );
      } on DioError catch (_) {
        // dio throws on 404
      }

      final event = fixture.transport.events.first;
      expect(fixture.transport.calls, 1);
      expect(event.request?.headers.isEmpty, true);
      expect(event.request?.cookies, isNull);
    });
  });
}

MockHttpClientAdapter createThrowingClient() {
  return MockHttpClientAdapter(
    (options, _, __) async {
      expect(options.uri, requestUri);
      throw TestException();
    },
  );
}

class CloseableMockClient extends Mock implements BaseClient {}

class Fixture {
  final _options = SentryOptions(dsn: fakeDsn);
  late Hub _hub;
  final transport = MockTransport();
  Fixture() {
    _options.transport = transport;
    _hub = Hub(_options);
  }

  Dio getSut({
    MockHttpClientAdapter? client,
    bool captureFailedRequests = false,
    MaxRequestBodySize maxRequestBodySize = MaxRequestBodySize.small,
    List<SentryStatusCode> badStatusCodes = const [],
    bool sendDefaultPii = true,
  }) {
    final mc = client ?? getClient();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    dio.httpClientAdapter = FailedRequestClientAdapter(
      client: mc,
      hub: _hub,
      captureFailedRequests: captureFailedRequests,
      failedRequestStatusCodes: badStatusCodes,
      maxRequestBodySize: maxRequestBodySize,
      sendDefaultPii: sendDefaultPii,
    );
    return dio;
  }

  MockHttpClientAdapter getClient({int statusCode = 200, String? reason}) {
    return MockHttpClientAdapter((options, requestStream, cancelFuture) async {
      expect(options.uri, requestUri);
      return ResponseBody.fromString('', statusCode);
    });
  }
}

class TestException implements Exception {}

class MaxRequestBodySizeTestConfig {
  MaxRequestBodySizeTestConfig(
    this.maxRequestBodySize,
    this.contentLength,
    this.shouldBeIncluded,
  );

  final MaxRequestBodySize maxRequestBodySize;
  final int contentLength;
  final bool shouldBeIncluded;
}
