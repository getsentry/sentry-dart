import 'dart:async';

import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/http_client/tracing_client.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import '../mocks/mock_transport.dart';
import '../test_utils.dart';

final requestUri = Uri.parse('https://example.com?foo=bar#baz');

class MockBeforeSendTransactionCallback extends Mock {
  FutureOr<SentryTransaction?> beforeSendTransaction(
    SentryTransaction? transaction,
    Hint? hint,
  );
}

void main() {
  group(TracingClient, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('beforeSendTransaction called for captured span', () async {
      var beforeSendTransaction =
          MockBeforeSendTransactionCallback().beforeSendTransaction;

      fixture._hub.options.beforeSendTransaction = beforeSendTransaction;
      final responseBody = "test response body";
      final sut = fixture.getSut(
        client: fixture.getClient(
            statusCode: 200, reason: 'OK', body: responseBody),
      );
      final tr = fixture._hub.startTransaction(
        'name',
        'op',
        bindToScope: true,
      );

      await sut.get(requestUri);

      await tr.finish();

      verify(beforeSendTransaction(
        any,
        any,
      )).called(1);
    });

    test(
        'beforeSendTransaction called with two httpResponses inside captured span',
        () async {
      SentryTransaction? transaction;
      Hint? hint;

      fixture._hub.options.beforeSendTransaction = (_transaction, _hint) {
        transaction = _transaction;
        hint = _hint;
        return transaction;
      };

      String firstResponseBody = "first response body";
      String secondResponseBody = "first response body";
      String responseBody = firstResponseBody;
      final sut = fixture.getSut(
        client: fixture.getClient(
            statusCode: 200, reason: 'OK', body: responseBody),
      );
      final tr = fixture._hub.startTransaction(
        'name',
        'op',
        bindToScope: true,
      );

      final firstOriginalResponse = await sut.get(requestUri);
      final firstOriginalResponseBody = firstOriginalResponse.body;

      responseBody = secondResponseBody;
      final secondOriginalResponse = await sut.get(requestUri);
      final secondOriginalResponseBody = secondOriginalResponse.body;

      await tr.finish();

      final transactionHintHttpResponse =
          hint!.get(TypeCheckHint.httpResponse) as StreamedResponse?;

      final firstHint = transaction!.spans[0].hint!;
      final secondHint = transaction!.spans[1].hint!;

      final firstHintHttpResponse =
          firstHint.get(TypeCheckHint.httpResponse) as StreamedResponse;
      final secondHintHttpResponse =
          secondHint.get(TypeCheckHint.httpResponse) as StreamedResponse;

      final firstHintHttpResponseBody =
          await firstHintHttpResponse.stream.bytesToString();
      final secondHintHttpResponseBody =
          await secondHintHttpResponse.stream.bytesToString();

      expect(transactionHintHttpResponse, null);

      expect(firstHintHttpResponseBody, firstResponseBody);
      expect(firstOriginalResponseBody, firstResponseBody);

      expect(secondHintHttpResponseBody, secondResponseBody);
      expect(secondOriginalResponseBody, secondResponseBody);
    });

    test('captured span if successful request without Pii', () async {
      final responseBody = "test response body";
      final sut = fixture.getSut(
        client: fixture.getClient(
            statusCode: 200, reason: 'OK', body: responseBody),
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
      expect(span.data['http.response_content_length'], responseBody.length);
      expect(span.data['http.response_content'], null);
      expect(span.origin, SentryTraceOrigins.autoHttpHttp);
    });

    test('captured span if successful request with Pii', () async {
      fixture._hub.options.sendDefaultPii = true;
      final responseBody = "test response body";
      final sut = fixture.getSut(
        client: fixture.getClient(
            statusCode: 200, reason: 'OK', body: responseBody),
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
      expect(span.data['http.response_content_length'], responseBody.length);
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

    test('set headers from propagationContext when tracing is disabled',
        () async {
      // ignore: deprecated_member_use_from_same_package
      fixture._options.enableTracing = false;
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
      );

      final propagationContext = fixture._hub.scope.propagationContext;
      propagationContext.baggage = SentryBaggage({'foo': 'bar'});

      final response = await sut.get(requestUri);

      expect(response.request!.headers['sentry-trace'],
          propagationContext.toSentryTrace().value);
      expect(response.request!.headers['baggage'], 'foo=bar');
    });

    test('set headers from propagationContext when no transaction', () async {
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
      );

      final propagationContext = fixture._hub.scope.propagationContext;
      propagationContext.baggage = SentryBaggage({'foo': 'bar'});

      final response = await sut.get(requestUri);

      expect(response.request!.headers['sentry-trace'],
          propagationContext.toSentryTrace().value);
      expect(response.request!.headers['baggage'], 'foo=bar');
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

  MockClient getClient({
    int statusCode = 200,
    // String body = '{}',
    String body = '',
    String? reason,
  }) {
    return MockClient((request) async {
      expect(request.url, requestUri);
      return Response(body, statusCode, reasonPhrase: reason, request: request);
    });
  }
}

class TestException implements Exception {}
