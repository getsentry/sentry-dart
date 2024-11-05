import 'dart:convert';

import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/http_client/failed_request_client.dart';
import 'package:test/test.dart';

import '../mocks.mocks.dart';
import '../mocks/mock_hub.dart' as fake;

final requestUri = Uri.parse('https://example.com');

void main() {
  group(SentryHttpClient, () {
    late Fixture fixture;
    late fake.MockHub fakeHub;
    late MockHub mockHub;

    setUp(() {
      fakeHub = fake.MockHub();
      mockHub = MockHub();
      fixture = Fixture();
    });

    test(
        'no captured events & one captured breadcrumb when everything goes well',
        () async {
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
        hub: fakeHub,
      );

      final response = await sut.get(requestUri);
      expect(response.statusCode, 200);

      expect(fakeHub.captureEventCalls.length, 0);
      expect(fakeHub.addBreadcrumbCalls.length, 1);
    });

    test('no captured event with default config', () async {
      fakeHub.options.captureFailedRequests = false;

      final sut = fixture.getSut(
        client: createThrowingClient(),
        hub: fakeHub,
      );

      await expectLater(() async => await sut.get(requestUri), throwsException);

      expect(fakeHub.captureEventCalls.length, 0);
      expect(fakeHub.addBreadcrumbCalls.length, 1);
    });

    test('captured event with override', () async {
      fakeHub.options.captureFailedRequests = false;

      final sut = fixture.getSut(
        client: createThrowingClient(),
        captureFailedRequests: true,
        hub: fakeHub,
      );

      await expectLater(() async => await sut.get(requestUri), throwsException);

      expect(fakeHub.captureEventCalls.length, 1);
    });

    test('one captured event with when enabling $FailedRequestClient',
        () async {
      fakeHub.options.captureFailedRequests = true;
      fakeHub.options.recordHttpBreadcrumbs = true;
      final sut = fixture.getSut(
        client: createThrowingClient(),
        hub: fakeHub,
      );

      await expectLater(() async => await sut.get(requestUri), throwsException);

      expect(fakeHub.captureEventCalls.length, 1);
      // The event should not have breadcrumbs from the BreadcrumbClient
      expect(fakeHub.captureEventCalls.first.event.breadcrumbs, null);
      // The breadcrumb for the request should still be added for every
      // following event.
      expect(fakeHub.addBreadcrumbCalls.length, 1);
    });

    test(
        'no captured event with when enabling $FailedRequestClient with override',
        () async {
      fakeHub.options.captureFailedRequests = true;
      final sut = fixture.getSut(
        client: createThrowingClient(),
        captureFailedRequests: false,
        hub: fakeHub,
      );

      await expectLater(() async => await sut.get(requestUri), throwsException);

      expect(fakeHub.captureEventCalls.length, 0);
    });

    test('close does get called for user defined client', () async {
      final mockHub = fake.MockHub();

      final mockClient = CloseableMockClient();

      final client = SentryHttpClient(client: mockClient, hub: mockHub);
      client.close();

      expect(fakeHub.addBreadcrumbCalls.length, 0);
      expect(fakeHub.captureExceptionCalls.length, 0);
      verify(mockClient.close());
    });

    test('no captured span if tracing disabled', () async {
      fakeHub.options.recordHttpBreadcrumbs = false;
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
        hub: fakeHub,
      );

      final response = await sut.get(requestUri);
      expect(response.statusCode, 200);

      expect(fakeHub.getSpanCalls, 0);
    });

    test('captured span if tracing enabled', () async {
      fakeHub.options.tracesSampleRate = 1.0;
      fakeHub.options.recordHttpBreadcrumbs = false;
      final sut = fixture.getSut(
          client: fixture.getClient(statusCode: 200, reason: 'OK'),
          hub: fakeHub);

      final response = await sut.get(requestUri);
      expect(response.statusCode, 200);

      expect(fakeHub.getSpanCalls, 1);
    });

    test('do not capture response body as hint if tracing disabled', () async {
      SentryOptions options = SentryOptions(dsn: "fake.dsn")
        ..recordHttpBreadcrumbs = false;
      when(mockHub.options).thenReturn(options);
      when(mockHub.getSpan()).thenReturn(null);
      when(mockHub.scope).thenReturn(fakeHub.scope);

      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
        hub: mockHub,
      );

      final response = await sut.get(requestUri);
      final responseBody = utf8.decode(response.bodyBytes);

      expect(responseBody, fixture.responseBody);

      verifyNever(mockHub.captureEvent(
        any,
        stackTrace: anyNamed('stackTrace'),
        hint: anyNamed('hint'),
      ));
    });

    test('capture response body as hint if tracing enabled', () async {
      SentryOptions options = SentryOptions(dsn: "fake.dsn")
        ..tracesSampleRate = 1.0
        ..recordHttpBreadcrumbs = false;
      when(mockHub.options).thenReturn(options);
      when(mockHub.getSpan()).thenReturn(null);
      when(mockHub.scope).thenReturn(fakeHub.scope);
      when(
        mockHub.captureEvent(
          any,
          stackTrace: anyNamed('stackTrace'),
          hint: anyNamed('hint'),
        ),
      ).thenAnswer((invocation) async {
        final hint = invocation.namedArguments[const Symbol('hint')] as Hint?;
        final response =
            hint?.get(TypeCheckHint.httpResponse) as StreamedResponse;
        final responseBody = await response.stream.bytesToString();

        expect(responseBody, fixture.responseBody);

        return SentryId.newId();
      });

      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
        hub: mockHub,
      );

      final response = await sut.get(requestUri);
      final responseBody = utf8.decode(response.bodyBytes);

      expect(responseBody, fixture.responseBody);
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
    required Hub hub,
  }) {
    final mc = client ?? getClient();
    return SentryHttpClient(
      client: mc,
      hub: hub,
      failedRequestStatusCodes: badStatusCodes,
      captureFailedRequests: captureFailedRequests,
    );
  }

  // final MockHub hub = MockHub();
  final String responseBody = "this is the content of the response_body";

  MockClient getClient({int statusCode = 200, String? reason}) {
    return MockClient((request) async {
      expect(request.url, requestUri);
      return Response(responseBody, statusCode, reasonPhrase: reason);
    });
  }
}

class TestException implements Exception {}
