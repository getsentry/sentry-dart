import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/http_client/tracing_client.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import '../mocks.dart';
import '../mocks/mock_transport.dart';

final requestUri = Uri.parse('https://example.com?foo=bar#baz');

void main() {
  group(TracingClient, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
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
      expect(span.data['http.method'], 'GET');
      expect(span.data['url'], 'https://example.com');
      expect(span.data['http.query'], 'foo=bar');
      expect(span.data['http.fragment'], 'baz');
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

    test('captured span adds sentry-trace header to the request', () async {
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
      final span = tracer.children.first;

      expect(response.request!.headers['sentry-trace'],
          span.toSentryTrace().value);
    });

    test('captured span adds baggage header to the request', () async {
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
      final span = tracer.children.first;
      final baggage = span.toBaggageHeader();
      final sentryTrace = span.toSentryTrace();

      expect(response.request!.headers[baggage!.name], baggage.value);
      expect(response.request!.headers[sentryTrace.name], sentryTrace.value);
    });

    test('captured span do not add headers if NoOp', () async {
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
      );

      await fixture._hub
          .configureScope((scope) => scope.span = NoOpSentrySpan());

      final response = await sut.get(requestUri);

      expect(response.request!.headers['baggage'], null);
      expect(response.request!.headers['sentry-trace'], null);
    });

    test('captured span do not add headers if origins not set', () async {
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
      final baggage = span.toBaggageHeader();

      expect(response.request!.headers[baggage!.name], isNull);
      expect(response.request!.headers[span.toSentryTrace().name], isNull);
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
  final _options = SentryOptions(dsn: fakeDsn);
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
      return Response('', statusCode, reasonPhrase: reason, request: request);
    });
  }
}

class TestException implements Exception {}
