// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'package:_sentry_testing/_sentry_testing.dart';
import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/span/instrumentation/span_factory_integration.dart';
import 'package:sentry_dio/src/failed_request_interceptor.dart';
import 'package:sentry_dio/src/tracing_client_adapter.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_http_client_adapter.dart';
import 'mocks/mock_transport.dart';

final requestUri = Uri.parse('https://example.com/api/users');

void main() {
  group('Dio SpanV2 Integration', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    tearDown(() {
      fixture.dispose();
    });

    test('HTTP GET creates spanv2', () async {
      final dio = fixture.getDio(
        mockAdapter: fixture.getMockAdapter(
          statusCode: 200,
          responseBody: '{"success": true}',
        ),
      );

      late SentrySpanV2 transactionSpan;
      await fixture.hub.startSpan('test-transaction', (span) async {
        transactionSpan = span;
        await dio.get<dynamic>('/api/users');
      }, parentSpan: null);

      await fixture.processor.waitForProcessing();

      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      final span = fixture.processor.findSpanByOperation('http.client');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      expect(
        span.attributes[SemanticAttributesConstants.sentryOp]?.value,
        equals('http.client'),
      );
      expect(
        span.attributes[SemanticAttributesConstants.httpRequestMethod]?.value,
        equals('GET'),
      );
      expect(
        span.attributes['url.full']?.value,
        equals('https://example.com/api/users'),
      );
      expect(
        span
            .attributes[SemanticAttributesConstants.httpResponseStatusCode]
            ?.value,
        equals(200),
      );
      expect(
        span.attributes[SemanticAttributesConstants.sentryOrigin]?.value,
        equals('auto.http.dio.http_client_adapter'),
      );

      expect(span.parentSpan, equals(transactionSpan));
      expect(span.traceId, equals(transactionSpan.traceId));
      expect(span.spanId, isNot(equals(transactionSpan.spanId)));
    });

    test('HTTP error creates spanv2 with error status', () async {
      final dio = fixture.getDio(
        mockAdapter: fixture.getMockAdapter(
          statusCode: 500,
          responseBody: '{"error": "Internal Server Error"}',
        ),
      );

      late SentrySpanV2 transactionSpan;
      await fixture.hub.startSpan('test-transaction', (span) async {
        transactionSpan = span;
        try {
          await dio.get<dynamic>('/api/users');
        } catch (_) {}
      }, parentSpan: null);

      await fixture.processor.waitForProcessing();

      final span = fixture.processor.findSpanByOperation('http.client');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);

      expect(span.status, equals(SentrySpanStatusV2.error));

      expect(
        span.attributes[SemanticAttributesConstants.sentryOp]?.value,
        equals('http.client'),
      );
      expect(span.parentSpan, equals(transactionSpan));
    });

    test('links a captured failed request to the request span', () async {
      final dio = fixture.getDio(
        mockAdapter: fixture.getRespondingAdapter(statusCode: 500),
        captureFailedRequests: true,
      );

      await fixture.hub.startSpan('segment', (_) async {
        await expectLater(dio.get<dynamic>('/api/users'), throwsA(anything));
      }, parentSpan: null);
      await fixture.processor.waitForProcessing();

      final httpSpan = fixture.processor.findSpanByOperation('http.client')!;
      final event = fixture.transport.events.single;
      expect(event.contexts.trace?.spanId, httpSpan.spanId);
      expect(event.transaction, 'segment');
    });

    test('links an error the app captures to the request span', () async {
      final dio = fixture.getDio(
        mockAdapter: fixture.getRespondingAdapter(statusCode: 500),
        captureFailedRequests: false,
      );

      Object? error;
      await fixture.hub.startSpan('segment', (_) async {
        try {
          await dio.get<dynamic>('/api/users');
        } catch (e) {
          error = e;
        }
      }, parentSpan: null);
      await fixture.hub.captureException(error);
      await fixture.processor.waitForProcessing();

      final httpSpan = fixture.processor.findSpanByOperation('http.client')!;
      final event = fixture.transport.events.single;
      expect(event.contexts.trace?.spanId, httpSpan.spanId);
    });
  });
}

class Fixture {
  late final Hub hub;
  late final SentryOptions options;
  late final FakeTelemetryProcessor processor;
  final transport = MockTransport();

  Fixture() {
    processor = FakeTelemetryProcessor();
    options = defaultTestOptions()
      ..tracesSampleRate = 1.0
      ..traceLifecycle = SentryTraceLifecycle.stream
      ..telemetryProcessor = processor
      ..transport = transport;
    hub = Hub(options);

    options.addIntegration(InstrumentationSpanFactorySetupIntegration());
    options.integrations.last.call(hub, options);
  }

  Dio getDio({
    required MockHttpClientAdapter mockAdapter,
    bool? captureFailedRequests,
  }) {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    dio.httpClientAdapter = TracingClientAdapter(client: mockAdapter, hub: hub);
    if (captureFailedRequests != null) {
      dio.interceptors.add(
        FailedRequestInterceptor(
          hub: hub,
          captureFailedRequests: captureFailedRequests,
        ),
      );
    }
    return dio;
  }

  /// Returns the response like a real adapter does, leaving Dio to raise the
  /// error for a bad status code after the adapter has returned.
  MockHttpClientAdapter getRespondingAdapter({required int statusCode}) {
    return MockHttpClientAdapter(
      (options, requestStream, cancelFuture) async =>
          ResponseBody.fromString('', statusCode),
    );
  }

  MockHttpClientAdapter getMockAdapter({
    required int statusCode,
    required String responseBody,
  }) {
    return MockHttpClientAdapter((options, requestStream, cancelFuture) async {
      final headers = <String, List<String>>{
        'content-type': ['application/json'],
      };

      if (statusCode >= 400) {
        throw DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: statusCode,
            data: responseBody,
            headers: Headers.fromMap(headers),
          ),
          type: DioExceptionType.badResponse,
        );
      }

      return ResponseBody.fromString(
        responseBody,
        statusCode,
        headers: headers,
      );
    });
  }

  void dispose() {
    processor.clear();
    hub.close();
  }
}
