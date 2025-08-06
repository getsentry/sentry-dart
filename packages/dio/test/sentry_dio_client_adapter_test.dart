// ignore_for_file: invalid_use_of_internal_member

import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_dio/src/sentry_dio_client_adapter.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_http_client_adapter.dart';
import 'mocks/mock_hub.dart';
import 'mocks/mock_transport.dart';

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

      expect(fixture.mockHub.captureEventCalls.length, 0);
      expect(fixture.mockHub.addBreadcrumbCalls.length, 1);
    });

    test('no captured event with default config', () async {
      final sut = fixture.getSut(
        client: createThrowingClient(),
      );

      await expectLater(
        () async => await sut.get<dynamic>('/'),
        throwsException,
      );

      expect(fixture.mockHub.captureEventCalls.length, 0);
      expect(fixture.mockHub.addBreadcrumbCalls.length, 1);
    });

    test('close does get called for user defined client', () async {
      final client = createCloseClient();
      final sut = fixture.getSut(client: client);

      sut.close(force: true);
    });

    test('no captured span if tracing disabled', () async {
      fixture.realHub.options.captureFailedRequests = false;
      fixture.realHub.options.recordHttpBreadcrumbs = false;
      final tr = fixture.realHub.startTransaction(
        'name',
        'op',
        bindToScope: true,
      );

      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
        hub: fixture.realHub,
      );
      final response = await sut.get<dynamic>('/');

      await tr.finish();

      expect(response.statusCode, 200);
      expect(tr, isA<NoOpSentrySpan>());
    });

    test('captured span if tracing enabled', () async {
      fixture.realHub.options.tracesSampleRate = 1.0;
      fixture.realHub.options.recordHttpBreadcrumbs = false;
      final tr = fixture.realHub.startTransaction(
        'name',
        'op',
        bindToScope: true,
      ) as SentryTracer;

      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
        hub: fixture.realHub,
      );
      final response = await sut.get<dynamic>('/');

      await tr.finish();

      expect(response.statusCode, 200);
      expect(tr.children.length, 1);
      expect(tr.children.first.context.operation, 'http.client');
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
  late MockHub mockHub;
  late Hub realHub;
  late MockTransport transport;
  final options = defaultTestOptions();

  Fixture() {
    // For some tests the real hub is needed, for other the mock is enough
    transport = MockTransport();
    options.transport = transport;
    realHub = Hub(options);
    mockHub = MockHub();
  }

  Dio getSut({
    MockHttpClientAdapter? client,
    MaxRequestBodySize maxRequestBodySize = MaxRequestBodySize.never,
    List<SentryStatusCode> badStatusCodes = const [],
    bool captureFailedRequests = true,
    Hub? hub,
  }) {
    final mc = client ?? getClient();
    hub ??= mockHub;
    final dio = Dio(BaseOptions(baseUrl: requestUri.toString()));
    hub.options.captureFailedRequests = captureFailedRequests;
    dio.httpClientAdapter = SentryDioClientAdapter(
      client: mc,
      hub: hub,
    );
    return dio;
  }

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
