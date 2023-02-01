import 'package:diox/diox.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_diox/src/sentry_diox_client_adapter.dart';
import 'package:test/test.dart';

import 'mocks/mock_http_client_adapter.dart';
import 'mocks/mock_hub.dart';

final requestUri = Uri.parse('https://example.com/');

void main() {
  group(SentryDioxClientAdapter, () {
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
        throwsA(isA<DioError>()),
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
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
        recordBreadcrumbs: false,
        networkTracing: false,
      );

      final response = await sut.get<dynamic>('/');
      expect(response.statusCode, 200);

      expect(fixture.hub.getSpanCalls, 0);
    });

    test('captured span if tracing enabled', () async {
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
        recordBreadcrumbs: false,
        networkTracing: true,
      );

      final response = await sut.get<dynamic>('/');
      expect(response.statusCode, 200);

      expect(fixture.hub.getSpanCalls, 1);
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
    bool captureFailedRequests = false,
    MaxRequestBodySize maxRequestBodySize = MaxRequestBodySize.never,
    List<SentryStatusCode> badStatusCodes = const [],
    bool recordBreadcrumbs = true,
    bool networkTracing = false,
  }) {
    final mc = client ?? getClient();
    final dio = Dio(BaseOptions(baseUrl: requestUri.toString()));
    dio.httpClientAdapter = SentryDioxClientAdapter(
      client: mc,
      hub: hub,
      recordBreadcrumbs: recordBreadcrumbs,
      networkTracing: networkTracing,
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
