import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/http_client/failed_request_client.dart';
import 'package:test/test.dart';

import '../mocks.dart';
import '../mocks/mock_hub.dart';
import '../mocks/mock_transport.dart';

final requestUri = Uri.parse('https://example.com?foo=bar#myFragment');

void main() {
  group(FailedRequestClient, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('no captured events when everything goes well', () async {
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200),
      );

      final response = await sut.get(requestUri);
      expect(response.statusCode, 200);

      expect(fixture.transport.calls, 0);
    });

    test('event reported if client throws', () async {
      final sut = fixture.getSut(
        client: createThrowingClient(),
        captureFailedRequests: true,
      );

      await expectLater(
        () async => await sut.get(requestUri, headers: {'Cookie': 'foo=bar'}),
        throwsException,
      );

      expect(fixture.transport.calls, 1);

      final eventCall = fixture.transport.events.first;
      final exception = eventCall.exceptions?.first;
      final mechanism = exception?.mechanism;

      expect(exception?.stackTrace, isNotNull);
      expect(exception?.stackTrace!.snapshot, isNull);
      expect(mechanism?.type, 'SentryHttpClient');

      final request = eventCall.request;
      expect(request, isNotNull);
      expect(request?.method, 'GET');
      expect(request?.url, 'https://example.com');
      expect(request?.queryString, 'foo=bar');
      expect(request?.fragment, 'myFragment');
      expect(request?.cookies, 'foo=bar');
      expect(request?.headers, {'Cookie': 'foo=bar'});
      // ignore: deprecated_member_use_from_same_package
      expect(request?.other.keys.contains('duration'), true);
      // ignore: deprecated_member_use_from_same_package
      expect(request?.other.keys.contains('content_length'), true);

      // Response is not captured in case of exception
      expect(eventCall.contexts.response, isNull);
    });

    test('event not reported if disabled', () async {
      final sut = fixture.getSut(
        client: createThrowingClient(),
        captureFailedRequests: false,
      );

      await expectLater(
        () async => await sut.get(requestUri, headers: {'Cookie': 'foo=bar'}),
        throwsException,
      );

      expect(fixture.transport.calls, 0);
    });

    test('event reported if bad status code occurs', () async {
      final sut = fixture.getSut(
        client: fixture.getClient(
            statusCode: 404,
            body: 'foo',
            headers: {'lorem': 'ipsum', 'set-cookie': 'foo=bar'}),
        badStatusCodes: [SentryStatusCode(404)],
      );

      await sut.get(requestUri, headers: {'Cookie': 'foo=bar'});

      expect(fixture.transport.calls, 1);

      final eventCall = fixture.transport.events.first;
      final exception = eventCall.exceptions?.first;
      final mechanism = exception?.mechanism;

      expect(mechanism?.type, 'SentryHttpClient');
      expect(mechanism?.handled, true);
      expect(
        mechanism?.description,
        'HTTP Client Error with status code: 404',
      );

      expect(exception?.type, 'SentryHttpClientError');
      expect(
        exception?.value,
        'Exception: HTTP Client Error with status code: 404',
      );
      expect(exception?.stackTrace?.snapshot, true);

      final request = eventCall.request;
      expect(request, isNotNull);
      expect(request?.method, 'GET');
      expect(request?.url, 'https://example.com');
      expect(request?.queryString, 'foo=bar');
      expect(request?.fragment, 'myFragment');
      expect(request?.cookies, 'foo=bar');
      expect(request?.headers, {'Cookie': 'foo=bar'});
      // ignore: deprecated_member_use_from_same_package
      expect(request?.other.keys.contains('duration'), true);
      // ignore: deprecated_member_use_from_same_package
      expect(request?.other.keys.contains('content_length'), true);

      final response = eventCall.contexts.response!;
      expect(response.bodySize, 3);
      expect(response.statusCode, 404);
      expect(response.headers,
          equals({'lorem': 'ipsum', 'set-cookie': 'foo=bar'}));
      expect(response.cookies, equals('foo=bar'));
    });

    test(
        'just one report on status code reporting with failing requests enabled',
        () async {
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 404),
        badStatusCodes: [SentryStatusCode(404)],
        captureFailedRequests: true,
      );

      await sut.get(requestUri, headers: {'Cookie': 'foo=bar'});

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
        () async => await sut.get(requestUri, headers: {'Cookie': 'foo=bar'}),
        throwsException,
      );

      final event = fixture.transport.events.first;
      expect(fixture.transport.calls, 1);
      expect(event.request, isNotNull);
      expect(event.request?.headers.isEmpty, true);
      expect(event.request?.cookies, isNull);
      expect(event.request?.data, isNull);
      expect(event.contexts.response, isNull);
    });

    test('pii is not send on invalid status code', () async {
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 404),
        badStatusCodes: [SentryStatusCode(404)],
        captureFailedRequests: false,
        sendDefaultPii: false,
      );

      await sut.get(requestUri, headers: {'Cookie': 'foo=bar'});

      final event = fixture.transport.events.first;
      expect(fixture.transport.calls, 1);
      expect(event.request, isNotNull);
      expect(event.request?.headers.isEmpty, true);
      expect(event.request?.cookies, isNull);
      expect(event.request?.data, isNull);
      expect(event.contexts.response, isNotNull);
      expect(event.contexts.response?.headers.isEmpty, true);
    });

    test('request body is included according to $MaxRequestBodySize', () async {
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
        fixture.transport.reset();

        final sut = fixture.getSut(
          client: createThrowingClient(),
          captureFailedRequests: true,
          maxRequestBodySize: scenario.maxBodySize,
        );

        final request = Request('GET', requestUri)
          // This creates a a request of the specified size
          ..bodyBytes = List.generate(scenario.contentLength, (index) => 0);

        await expectLater(
          () async => await sut.send(request),
          throwsException,
        );

        expect(fixture.transport.calls, 1);

        final eventCall = fixture.transport.events.first;
        final capturedRequest = eventCall.request;
        expect(capturedRequest, isNotNull);
        expect(capturedRequest?.data, scenario.matcher);
      }
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
  final _options = SentryOptions(dsn: fakeDsn);
  late Hub _hub;
  final transport = MockTransport();
  Fixture() {
    _options.transport = transport;
    _hub = Hub(_options);
  }

  FailedRequestClient getSut({
    MockClient? client,
    bool captureFailedRequests = false,
    MaxRequestBodySize maxRequestBodySize = MaxRequestBodySize.small,
    List<SentryStatusCode> badStatusCodes = const [],
    bool sendDefaultPii = true,
  }) {
    final mc = client ?? getClient();
    return FailedRequestClient(
      client: mc,
      hub: _hub,
      captureFailedRequests: captureFailedRequests,
      failedRequestStatusCodes: badStatusCodes,
      maxRequestBodySize: maxRequestBodySize,
      sendDefaultPii: sendDefaultPii,
    );
  }

  MockClient getClient(
      {int statusCode = 200,
      String body = '',
      Map<String, String> headers = const {}}) {
    return MockClient((request) async {
      expect(request.url, requestUri);
      return Response(body, statusCode, headers: headers);
    });
  }
}

class TestException implements Exception {}

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
