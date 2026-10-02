// ignore_for_file: invalid_use_of_internal_member

import 'package:_sentry_testing/_sentry_testing.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/http_client/failed_request_client.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry/src/tracing/instrumentation/span_factory_integration.dart';
import 'package:test/test.dart';

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

    group('when streaming spans and a failed request is captured', () {
      setUp(() => fixture.enableSpanStreaming());

      test('links the error to the http.client span', () async {
        final sut = fixture.getSut(
          hub: fixture.realHub,
          client: fixture.getClient(statusCode: 500),
          badStatusCodes: [SentryStatusCode.range(500, 599)],
          captureFailedRequests: true,
        );

        late SentrySpanV2 rootSpan;
        await fixture.realHub.startSpan('root-span', (span) async {
          rootSpan = span;
          await sut.get(requestUri);
        });

        await fixture.processor.waitForProcessing();
        final httpSpan = fixture.processor.findSpanByOperation('http.client')!;

        final traceContext = fixture.transport.events.first.contexts.trace;
        expect(traceContext?.spanId, httpSpan.spanId);
        expect(traceContext?.parentSpanId, rootSpan.spanId);
        expect(traceContext?.traceId, rootSpan.traceId);
        expect(traceContext?.operation, 'http.client');
      });

      test('links the error to the http.client span when the client throws',
          () async {
        final sut = fixture.getSut(
          hub: fixture.realHub,
          client: createThrowingClient(),
          captureFailedRequests: true,
        );

        await fixture.realHub.startSpan('root-span', (_) async {
          await expectLater(
              () => sut.get(requestUri), throwsA(isA<Exception>()));
        });

        await fixture.processor.waitForProcessing();
        final httpSpan = fixture.processor.findSpanByOperation('http.client')!;

        expect(fixture.transport.events.first.contexts.trace?.spanId,
            httpSpan.spanId);
      });

      test('does not link the error when no span is active', () async {
        final sut = fixture.getSut(
          hub: fixture.realHub,
          client: fixture.getClient(statusCode: 500),
          badStatusCodes: [SentryStatusCode.range(500, 599)],
          captureFailedRequests: true,
        );

        await sut.get(requestUri);

        expect(fixture.processor.findSpanByOperation('http.client'), isNull);
        expect(fixture.transport.events.first.contexts.trace?.parentSpanId,
            isNull);
      });
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
  final processor = FakeTelemetryProcessor();
  final options = defaultTestOptions();

  Fixture() {
    // For some tests the real hub is needed, for other the mock is enough
    transport = MockTransport();
    options.transport = transport;
    realHub = Hub(options);
    mockHub = MockHub();
  }

  void enableSpanStreaming() {
    options.tracesSampleRate = 1.0;
    options.recordHttpBreadcrumbs = false;
    options.traceLifecycle = SentryTraceLifecycle.stream;
    options.telemetryProcessor = processor;
    options.addIntegration(InstrumentationSpanFactorySetupIntegration());
    options.integrations.last.call(realHub, options);
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
