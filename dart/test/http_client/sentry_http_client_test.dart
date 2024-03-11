import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/http_client/failed_request_client.dart';
import 'package:test/test.dart';

import '../mocks/mock_hub.dart';

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

      expect(fixture.hub.captureEventCalls.length, 0);
      expect(fixture.hub.addBreadcrumbCalls.length, 1);
    });

    test('no captured event with default config', () async {
      fixture.hub.options.captureFailedRequests = false;

      final sut = fixture.getSut(
        client: createThrowingClient(),
      );

      await expectLater(() async => await sut.get(requestUri), throwsException);

      expect(fixture.hub.captureEventCalls.length, 0);
      expect(fixture.hub.addBreadcrumbCalls.length, 1);
    });

    test('captured event with override', () async {
      fixture.hub.options.captureFailedRequests = false;

      final sut = fixture.getSut(
        client: createThrowingClient(),
        captureFailedRequests: true,
      );

      await expectLater(() async => await sut.get(requestUri), throwsException);

      expect(fixture.hub.captureEventCalls.length, 1);
    });

    test('one captured event with when enabling $FailedRequestClient',
        () async {
      fixture.hub.options.captureFailedRequests = true;
      fixture.hub.options.recordHttpBreadcrumbs = true;
      final sut = fixture.getSut(
        client: createThrowingClient(),
      );

      await expectLater(() async => await sut.get(requestUri), throwsException);

      expect(fixture.hub.captureEventCalls.length, 1);
      // The event should not have breadcrumbs from the BreadcrumbClient
      expect(fixture.hub.captureEventCalls.first.event.breadcrumbs, null);
      // The breadcrumb for the request should still be added for every
      // following event.
      expect(fixture.hub.addBreadcrumbCalls.length, 1);
    });

    test(
        'no captured event with when enabling $FailedRequestClient with override',
        () async {
      fixture.hub.options.captureFailedRequests = true;
      final sut = fixture.getSut(
        client: createThrowingClient(),
        captureFailedRequests: false,
      );

      await expectLater(() async => await sut.get(requestUri), throwsException);

      expect(fixture.hub.captureEventCalls.length, 0);
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
      fixture.hub.options.recordHttpBreadcrumbs = false;
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
      );

      final response = await sut.get(requestUri);
      expect(response.statusCode, 200);

      expect(fixture.hub.getSpanCalls, 0);
    });

    test('captured span if tracing enabled', () async {
      fixture.hub.options.tracesSampleRate = 1.0;
      fixture.hub.options.recordHttpBreadcrumbs = false;
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
      );

      final response = await sut.get(requestUri);
      expect(response.statusCode, 200);

      expect(fixture.hub.getSpanCalls, 1);
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
  SentryHttpClient getSut({
    MockClient? client,
    List<SentryStatusCode> badStatusCodes = const [],
    bool? captureFailedRequests,
  }) {
    final mc = client ?? getClient();
    return SentryHttpClient(
      client: mc,
      hub: hub,
      failedRequestStatusCodes: badStatusCodes,
      captureFailedRequests: captureFailedRequests,
    );
  }

  final MockHub hub = MockHub();

  MockClient getClient({int statusCode = 200, String? reason}) {
    return MockClient((request) async {
      expect(request.url, requestUri);
      return Response('', statusCode, reasonPhrase: reason);
    });
  }
}

class TestException implements Exception {}
