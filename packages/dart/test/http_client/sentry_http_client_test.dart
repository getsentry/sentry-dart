import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/http_client/failed_request_client.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import '../mocks/mock_hub.dart';
import '../mocks/mock_transport.dart';
import '../test_utils.dart';

final requestUri = Uri.parse('https://example.com');

void main() {
  group(SentryHttpClient, () {
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

      final response = await sut.get(requestUri);
      expect(response.statusCode, 200);

      expect(fixture.mockHub.captureEventCalls.length, 0);
      expect(fixture.mockHub.addBreadcrumbCalls.length, 1);
    });

    test('no captured event with default config', () async {
      fixture.mockHub.options.captureFailedRequests = false;

      final sut = fixture.getSut(
        client: createThrowingClient(),
      );

      await expectLater(() async => await sut.get(requestUri), throwsException);

      expect(fixture.mockHub.captureEventCalls.length, 0);
      expect(fixture.mockHub.addBreadcrumbCalls.length, 1);
    });

    test('captured event with override', () async {
      fixture.mockHub.options.captureFailedRequests = false;

      final sut = fixture.getSut(
        client: createThrowingClient(),
        captureFailedRequests: true,
      );

      await expectLater(() async => await sut.get(requestUri), throwsException);

      expect(fixture.mockHub.captureEventCalls.length, 1);
    });

    test('one captured event with when enabling $FailedRequestClient',
        () async {
      fixture.mockHub.options.captureFailedRequests = true;
      fixture.mockHub.options.recordHttpBreadcrumbs = true;
      final sut = fixture.getSut(
        client: createThrowingClient(),
      );

      await expectLater(() async => await sut.get(requestUri), throwsException);

      expect(fixture.mockHub.captureEventCalls.length, 1);
      // The event should not have breadcrumbs from the BreadcrumbClient
      expect(fixture.mockHub.captureEventCalls.first.event.breadcrumbs, null);
      // The breadcrumb for the request should still be added for every
      // following event.
      expect(fixture.mockHub.addBreadcrumbCalls.length, 1);
    });

    test(
        'no captured event with when enabling $FailedRequestClient with override',
        () async {
      fixture.mockHub.options.captureFailedRequests = true;
      final sut = fixture.getSut(
        client: createThrowingClient(),
        captureFailedRequests: false,
      );

      await expectLater(() async => await sut.get(requestUri), throwsException);

      expect(fixture.mockHub.captureEventCalls.length, 0);
    });

    test('close does get called for user defined client', () async {
      final mockHub = MockHub();

      final mockClient = CloseableMockClient();

      final client = SentryHttpClient(client: mockClient, hub: mockHub);
      client.close();

      expect(mockHub.addBreadcrumbCalls.length, 0);
      expect(mockHub.captureExceptionCalls.length, 0);
      verify(mockClient.close());
    });

    test('no captured span if tracing disabled', () async {
      fixture.realHub.options.recordHttpBreadcrumbs = false;
      final tr = fixture.realHub.startTransaction(
        'name',
        'op',
        bindToScope: true,
      );

      final sut = fixture.getSut(
        hub: fixture.realHub,
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
      );
      final response = await sut.get(requestUri);

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
      final response = await sut.get(requestUri);

      await tr.finish();

      expect(response.statusCode, 200);
      expect(tr.children.length, 1);
      expect(tr.children.first.context.operation, 'http.client');
    });
  });
}

MockClient createThrowingClient() {
  return MockClient(
    (request) async {
      expect(request.url, requestUri);
      throw TestException();
    },
  );
}

class CloseableMockClient extends Mock implements BaseClient {}

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

  SentryHttpClient getSut({
    MockClient? client,
    List<SentryStatusCode> badStatusCodes = const [],
    bool? captureFailedRequests,
    Hub? hub,
  }) {
    final mc = client ?? getClient();
    hub ??= mockHub;
    return SentryHttpClient(
      client: mc,
      hub: hub,
      failedRequestStatusCodes: badStatusCodes,
      captureFailedRequests: captureFailedRequests,
    );
  }

  MockClient getClient({int statusCode = 200, String? reason}) {
    return MockClient((request) async {
      expect(request.url, requestUri);
      return Response('', statusCode, reasonPhrase: reason);
    });
  }
}

class TestException implements Exception {}
