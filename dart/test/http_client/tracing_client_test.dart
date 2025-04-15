import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/http_client/tracing_client.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import '../mocks/mock_transport.dart';
import '../test_utils.dart';

final requestUri = Uri.parse('https://example.com?foo=bar#baz');

void main() {
  group(TracingClient, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('should add sdk integration on init when tracing is enabled',
        () async {
      fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
      );

      expect(fixture._hub.options.isTracingEnabled(), isTrue);
      expect(fixture._hub.options.sdk.integrations,
          contains(TracingClient.integrationName));
    });

    test('should not add sdk integration on init when tracing is disabled',
        () async {
      fixture._hub.options.tracesSampleRate = null;
      fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
      );

      expect(fixture._hub.options.isTracingEnabled(), isFalse);
      expect(fixture._hub.options.sdk.integrations,
          isNot(contains(TracingClient.integrationName)));
    });

    test('captured span if successful request', () async {
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
      );
      final tr = fixture._hub.startTransaction(
        'name',
        'op',
        bindToScope: true,
      );

      await sut.get(requestUri);

      await tr.finish();

      final tracer = (tr as SentryTracer);
      final span = tracer.children.first;

      expect(span.status, SpanStatus.ok());
      expect(span.context.operation, 'http.client');
      expect(span.context.description, 'GET https://example.com');
      expect(span.data['http.request.method'], 'GET');
      expect(span.data['url'], 'https://example.com');
      expect(span.data['http.query'], 'foo=bar');
      expect(span.data['http.fragment'], 'baz');
      expect(span.data['http.response.status_code'], 200);
      expect(span.data['http.response_content_length'], 2);
      expect(span.origin, SentryTraceOrigins.autoHttpHttp);
    });

    test('finish span if errored request', () async {
      final sut = fixture.getSut(
        client: createThrowingClient(),
      );
      final tr = fixture._hub.startTransaction(
        'name',
        'op',
        bindToScope: true,
      );

      try {
        await sut.get(requestUri);
      } catch (_) {
        // ignore
      }

      await tr.finish();

      final tracer = (tr as SentryTracer);
      final span = tracer.children.first;

      expect(span.finished, isTrue);
    });

    test('associate exception to span if errored request', () async {
      final sut = fixture.getSut(
        client: createThrowingClient(),
      );
      final tr = fixture._hub.startTransaction(
        'name',
        'op',
        bindToScope: true,
      );

      dynamic exception;
      try {
        await sut.get(requestUri);
      } catch (error) {
        exception = error;
      }

      await tr.finish();

      final tracer = (tr as SentryTracer);
      final span = tracer.children.first;

      expect(span.status, SpanStatus.internalError());
      expect(span.throwable, exception);
    });

    test('should add tracing headers from span when tracing enabled', () async {
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
      );
      final tr = fixture._hub.startTransaction(
        'name',
        'op',
        bindToScope: true,
      );

      final response = await sut.get(requestUri);

      await tr.finish();

      final tracer = (tr as SentryTracer);
      expect(tracer.children.length, 1);
      final span = tracer.children.first;
      final baggageHeader = span.toBaggageHeader();
      final sentryTraceHeader = span.toSentryTrace();

      expect(
          response.request!.headers[baggageHeader!.name], baggageHeader.value);
      expect(response.request!.headers[sentryTraceHeader.name],
          sentryTraceHeader.value);
    });

    test(
        'should add tracing headers from propagation context when tracing disabled',
        () async {
      fixture._hub.options.tracesSampleRate = null;
      fixture._hub.options.tracesSampler = null;
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
      );
      final propagationContext = fixture._hub.scope.propagationContext;
      propagationContext.baggage = SentryBaggage({'foo': 'bar'});

      final response = await sut.get(requestUri);

      final baggageHeader = propagationContext.toBaggageHeader();
      final sentryTraceHeader = propagationContext.toSentryTrace();

      expect(propagationContext.toBaggageHeader(), isNotNull);
      expect(
          response.request!.headers[baggageHeader!.name], baggageHeader.value);
      expect(response.request!.headers[sentryTraceHeader.name],
          sentryTraceHeader.value);
    });

    test(
        'should not add tracing headers when URL does not match tracePropagationTargets with tracing enabled',
        () async {
      final sut = fixture.getSut(
        client: fixture.getClient(
          statusCode: 200,
          reason: 'OK',
        ),
        tracePropagationTargets: ['nope'],
      );
      final tr = fixture._hub.startTransaction(
        'name',
        'op',
        bindToScope: true,
      );

      final response = await sut.get(requestUri);

      await tr.finish();

      final tracer = (tr as SentryTracer);
      final span = tracer.children.first;
      final baggageHeader = span.toBaggageHeader();
      final sentryTraceHeader = span.toSentryTrace();

      expect(response.request!.headers[baggageHeader!.name], isNull);
      expect(response.request!.headers[sentryTraceHeader.name], isNull);
    });

    test(
        'should not add tracing headers when URL does not match tracePropagationTargets with tracing disabled',
        () async {
      fixture._hub.options.tracesSampleRate = null;
      fixture._hub.options.tracesSampler = null;
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
        tracePropagationTargets: ['nope'],
      );
      final propagationContext = fixture._hub.scope.propagationContext;
      propagationContext.baggage = SentryBaggage({'foo': 'bar'});

      final response = await sut.get(requestUri);

      final baggageHeader = propagationContext.toBaggageHeader();
      final sentryTraceHeader = propagationContext.toSentryTrace();

      expect(response.request!.headers[baggageHeader!.name], isNull);
      expect(response.request!.headers[sentryTraceHeader.name], isNull);
    });

    test('do not throw if no span bound to the scope', () async {
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
      );

      await sut.get(requestUri);
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

class Fixture {
  final _options = defaultTestOptions();
  late Hub _hub;
  final transport = MockTransport();
  Fixture() {
    _options.transport = transport;
    _options.tracesSampleRate = 1.0;
    _hub = Hub(_options);
  }

  TracingClient getSut({
    MockClient? client,
    List<String>? tracePropagationTargets,
  }) {
    if (tracePropagationTargets != null) {
      _hub.options.tracePropagationTargets.clear();
      _hub.options.tracePropagationTargets.addAll(tracePropagationTargets);
    }
    final mc = client ?? getClient();
    return TracingClient(
      client: mc,
      hub: _hub,
    );
  }

  MockClient getClient({int statusCode = 200, String? reason}) {
    return MockClient((request) async {
      expect(request.url, requestUri);
      return Response('{}', statusCode, reasonPhrase: reason, request: request);
    });
  }
}

class TestException implements Exception {}
