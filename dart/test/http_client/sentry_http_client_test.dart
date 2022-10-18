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
      final sut = fixture.getSut(
        client: createThrowingClient(),
      );

      await expectLater(() async => await sut.get(requestUri), throwsException);

      expect(fixture.hub.captureEventCalls.length, 0);
      expect(fixture.hub.addBreadcrumbCalls.length, 1);
    });

    test('one captured event with when enabling $FailedRequestClient',
        () async {
      final sut = fixture.getSut(
        client: createThrowingClient(),
        captureFailedRequests: true,
        recordBreadcrumbs: true,
      );

      await expectLater(() async => await sut.get(requestUri), throwsException);

      expect(fixture.hub.captureEventCalls.length, 1);
      // The event should not have breadcrumbs from the BreadcrumbClient
      expect(fixture.hub.captureEventCalls.first.event.breadcrumbs, null);
      // The breadcrumb for the request should still be added for every
      // following event.
      expect(fixture.hub.addBreadcrumbCalls.length, 1);
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
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
        recordBreadcrumbs: false,
        networkTracing: false,
      );

      final response = await sut.get(requestUri);
      expect(response.statusCode, 200);

      expect(fixture.hub.getSpanCalls, 0);
    });

    test('captured span if tracing enabled', () async {
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
        recordBreadcrumbs: false,
        networkTracing: true,
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
    bool captureFailedRequests = false,
    MaxRequestBodySize maxRequestBodySize = MaxRequestBodySize.never,
    List<SentryStatusCode> badStatusCodes = const [],
    bool recordBreadcrumbs = true,
    bool networkTracing = false,
  }) {
    final mc = client ?? getClient();
    return SentryHttpClient(
      client: mc,
      hub: hub,
      captureFailedRequests: captureFailedRequests,
      failedRequestStatusCodes: badStatusCodes,
      maxRequestBodySize: maxRequestBodySize,
      recordBreadcrumbs: recordBreadcrumbs,
      networkTracing: networkTracing,
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
