// ignore_for_file: invalid_use_of_internal_member, deprecated_member_use
// The lint above is okay, because we're using another Sentry package

import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_dio/src/tracing_client_adapter.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_http_client_adapter.dart';
import 'mocks/mock_transport.dart';

final requestUri = Uri.parse('https://example.com?foo=bar#baz');
final requestOptions = '?foo=bar#baz';

void main() {
  group(TracingClientAdapter, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test(
      'should add sdk integration on init when tracing is enabled',
      () async {
        fixture.getSut(
          client: fixture.getClient(statusCode: 200, reason: 'OK'),
        );

        expect(fixture._hub.options.isTracingEnabled(), isTrue);
        expect(
          fixture._hub.options.sdk.integrations,
          contains(TracingClientAdapter.integrationName),
        );
      },
    );

    test(
      'should not add sdk integration on init when tracing is disabled',
      () async {
        fixture._hub.options.tracesSampleRate = null;
        fixture.getSut(
          client: fixture.getClient(statusCode: 200, reason: 'OK'),
        );

        expect(fixture._hub.options.isTracingEnabled(), isFalse);
        expect(
          fixture._hub.options.sdk.integrations,
          isNot(contains(TracingClientAdapter.integrationName)),
        );
      },
    );

    test('captured span if successful request', () async {
      final sut = fixture.getSut(
        client: fixture.getClient(
          statusCode: 200,
          reason: 'OK',
          contentLength: 2,
        ),
      );
      final tr = fixture._hub.startTransaction('name', 'op', bindToScope: true);

      await sut.get<dynamic>(requestOptions);

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
      expect(span.origin, SentryTraceOrigins.autoHttpDioHttpClientAdapter);
    });

    test('finish span if errored request', () async {
      final sut = fixture.getSut(client: createThrowingClient());
      final tr = fixture._hub.startTransaction('name', 'op', bindToScope: true);

      try {
        await sut.get<dynamic>(requestOptions);
      } catch (_) {
        // ignore
      }

      await tr.finish();

      final tracer = (tr as SentryTracer);
      final span = tracer.children.first;

      expect(span.finished, isTrue);
    });

    test('associate exception to span if errored request', () async {
      final sut = fixture.getSut(client: createThrowingClient());
      final tr = fixture._hub.startTransaction('name', 'op', bindToScope: true);

      dynamic exception;
      try {
        await sut.get<dynamic>(requestOptions);
      } catch (error) {
        exception = error;
      }

      await tr.finish();

      final tracer = (tr as SentryTracer);
      final span = tracer.children.first;

      expect(span.status, SpanStatus.internalError());
      expect(span.throwable, isA<TestException>());
      expect(exception, isA<DioError>());
      expect((exception as DioError).error, isA<TestException>());
    });

    for (final propagate in <bool>[true, false]) {
      test(
        'should add tracing headers from span when tracing is enabled (propagateTraceparent: $propagate)',
        () async {
          final sut = fixture.getSut(
            client: fixture.getClient(statusCode: 200, reason: 'OK'),
          );
          fixture._hub.options.propagateTraceparent = propagate;

          final tr = fixture._hub.startTransaction(
            'name',
            'op',
            bindToScope: true,
          );

          final response = await sut.get<dynamic>(requestOptions);

          await tr.finish();

          final tracer = (tr as SentryTracer);
          final span = tracer.children.first;
          final baggageHeader = span.toBaggageHeader();
          final sentryTraceHeader = span.toSentryTrace();

          expect(response.headers[baggageHeader!.name], <String>[
            baggageHeader.value,
          ]);
          expect(response.headers[sentryTraceHeader.name], <String>[
            sentryTraceHeader.value,
          ]);

          final traceHeader = span.toSentryTrace();
          final expected =
              '00-${traceHeader.traceId}-${traceHeader.spanId}-${traceHeader.sampled == true ? '01' : '00'}';

          if (propagate) {
            expect(response.headers['traceparent'], <String>[expected]);
          } else {
            expect(response.headers['traceparent'], isNull);
          }
        },
      );

      test(
        'should add tracing headers from propagation context when tracing is disabled (propagateTraceparent: $propagate)',
        () async {
          fixture._options.tracesSampleRate = null;
          fixture._options.tracesSampler = null;
          fixture._hub.options.propagateTraceparent = propagate;

          final sut = fixture.getSut(
            client: fixture.getClient(statusCode: 200, reason: 'OK'),
          );
          final propagationContext = fixture._hub.scope.propagationContext;
          propagationContext.baggage = SentryBaggage({'foo': 'bar'});

          final response = await sut.get<dynamic>(requestOptions);

          final baggageHeader = propagationContext.toBaggageHeader();

          expect(propagationContext.toBaggageHeader(), isNotNull);
          expect(response.headers[baggageHeader!.name], <String>[
            baggageHeader.value,
          ]);

          final traceHeader = SentryTraceHeader.fromTraceHeader(
            response.headers['sentry-trace']?.first as String,
          );
          expect(traceHeader.traceId, propagationContext.traceId);

          if (propagate) {
            final headerValue = response.headers['traceparent']!.first;
            final parts = headerValue.split('-');
            expect(parts.length, 4);
            expect(parts[0], '00');
            expect(
              parts[1],
              fixture._hub.scope.propagationContext.traceId.toString(),
            );
            expect(parts[2].length, 16);
            expect(parts[3], '00');
          } else {
            expect(response.headers['traceparent'], isNull);
          }
        },
      );
    }

    test(
      'should create header with new generated span id for request when tracing is disabled',
      () async {
        fixture._options.tracesSampleRate = null;
        fixture._options.tracesSampler = null;
        final sut = fixture.getSut(
          client: fixture.getClient(statusCode: 200, reason: 'OK'),
        );

        final response1 = await sut.get<dynamic>(requestOptions);
        final response2 = await sut.get<dynamic>(requestOptions);

        final header1 = SentryTraceHeader.fromTraceHeader(
          response1.headers['sentry-trace']?.first as String,
        );
        final header2 = SentryTraceHeader.fromTraceHeader(
          response2.headers['sentry-trace']?.first as String,
        );
        expect(header1.spanId, isNot(header2.spanId));
      },
    );

    test(
      'should not add tracing headers when URL does not match tracePropagationTargets with tracing enabled',
      () async {
        final sut = fixture.getSut(
          client: fixture.getClient(statusCode: 200, reason: 'OK'),
          tracePropagationTargets: ['nope'],
        );
        final tr = fixture._hub.startTransaction(
          'name',
          'op',
          bindToScope: true,
        );

        final response = await sut.get<dynamic>(requestOptions);

        await tr.finish();

        final tracer = (tr as SentryTracer);
        final span = tracer.children.first;
        final baggageHeader = span.toBaggageHeader();
        final sentryTraceHeader = span.toSentryTrace();

        expect(response.headers[baggageHeader!.name], isNull);
        expect(response.headers[sentryTraceHeader.name], isNull);
        expect(response.headers['traceparent'], isNull);
      },
    );

    test(
      'should not add tracing headers when URL does not match tracePropagationTargets with tracing disabled',
      () async {
        final sut = fixture.getSut(
          client: fixture.getClient(statusCode: 200, reason: 'OK'),
          tracePropagationTargets: ['nope'],
        );
        final propagationContext = fixture._hub.scope.propagationContext;
        propagationContext.baggage = SentryBaggage({'foo': 'bar'});

        final response = await sut.get<dynamic>(requestOptions);

        final baggageHeader = propagationContext.toBaggageHeader();
        final sentryTraceHeader = propagationContext.toSentryTrace();

        expect(response.headers[baggageHeader!.name], isNull);
        expect(response.headers[sentryTraceHeader.name], isNull);
        expect(response.headers['traceparent'], isNull);
      },
    );

    test('do not throw if no span bound to the scope', () async {
      final sut = fixture.getSut(
        client: fixture.getClient(statusCode: 200, reason: 'OK'),
      );

      await sut.get<dynamic>(requestOptions);
    });
  });
}

MockHttpClientAdapter createThrowingClient() {
  return MockHttpClientAdapter((options, _, __) async {
    expect(options.uri, requestUri);
    throw TestException();
  });
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

  Dio getSut({
    MockHttpClientAdapter? client,
    List<String>? tracePropagationTargets,
  }) {
    final mc = client ?? getClient();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    if (tracePropagationTargets != null) {
      _hub.options.tracePropagationTargets.clear();
      _hub.options.tracePropagationTargets.addAll(tracePropagationTargets);
    }
    dio.httpClientAdapter = TracingClientAdapter(client: mc, hub: _hub);
    return dio;
  }

  MockHttpClientAdapter getClient({
    int statusCode = 200,
    String? reason,
    int? contentLength,
  }) {
    return MockHttpClientAdapter((options, requestStream, cancelFuture) async {
      expect(options.uri, requestUri);

      final headers = options.headers.map(
        (key, dynamic value) =>
            MapEntry(key, <String>[value?.toString() ?? '']),
      );

      if (contentLength != null) {
        headers['Content-Length'] = [contentLength.toString()];
      }

      return ResponseBody.fromString('{}', statusCode, headers: headers);
    });
  }
}

class TestException implements Exception {}
