import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_dio/src/sentry_dio_client_adapter.dart';
import 'package:test/test.dart';

import 'mocks/mock_http_client_adapter.dart';
import 'mocks/mock_hub.dart';

final requestUri = Uri.parse('https://example.com/');

void main() {
  group(SentryDioClientAdapter, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test(
        'no captured events & one captured breadcrumb when everything goes well',
        () async {
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
      );

      final response = await sut.get<dynamic>('/');
      expect(response.statusCode, 200);

      expect(fixture.hub.captureEventCalls.length, 0);
      expect(fixture.hub.addBreadcrumbCalls.length, 1);
    });

    test('no captured event with default config', () async {
      final sut = fixture.getSut(
        client: createThrowingClient(),
      );

      await expectLater(
        () async => await sut.get<dynamic>('/'),
        throwsException,
      );

      expect(fixture.hub.captureEventCalls.length, 0);
      expect(fixture.hub.addBreadcrumbCalls.length, 1);
    });

    test('close does get called for user defined client', () async {
      final client = createCloseClient();
      final sut = fixture.getSut(client: client);

      sut.close(force: true);
    });

    test('no captured span if tracing disabled', () async {
      fixture.hub.options.captureFailedRequests = false;
      fixture.hub.options.recordHttpBreadcrumbs = false;
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
      );

      final response = await sut.get<dynamic>('/');
      expect(response.statusCode, 200);

      expect(fixture.hub.getSpanCalls, 0);
    });

    test('captured span if tracing enabled', () async {
      fixture.hub.options.recordHttpBreadcrumbs = false;
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
      );

      final response = await sut.get<dynamic>('/');
      expect(response.statusCode, 200);

      expect(fixture.hub.getSpanCalls, 0);
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

void _close({bool force = false}) {
  expect(force, true);
}

MockHttpClientAdapter createCloseClient() {
  return MockHttpClientAdapter(
    (_, __, ___) async {
      return ResponseBody.fromString('', 200);
    },
    mockCloseMethod: _close,
  );
}

class Fixture {
  Dio getSut({
    MockHttpClientAdapter? client,
    MaxRequestBodySize maxRequestBodySize = MaxRequestBodySize.never,
    List<SentryStatusCode> badStatusCodes = const [],
    bool captureFailedRequests = true,
  }) {
    final mc = client ?? getClient();
    final dio = Dio(BaseOptions(baseUrl: requestUri.toString()));
    hub.options.captureFailedRequests = captureFailedRequests;
    dio.httpClientAdapter = SentryDioClientAdapter(
      client: mc,
      hub: hub,
    );
    return dio;
  }

  final MockHub hub = MockHub();

  MockHttpClientAdapter getClient({int statusCode = 200, String? reason}) {
    return MockHttpClientAdapter(
      (options, _, __) async {
        expect(options.uri, requestUri);
        return ResponseBody.fromString('', statusCode);
      },
    );
  }
}

class TestException implements Exception {}
