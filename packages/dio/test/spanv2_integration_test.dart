// ignore_for_file: invalid_use_of_internal_member

import 'package:_sentry_testing/_sentry_testing.dart';
import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/tracing/instrumentation/span_factory_integration.dart';
import 'package:sentry_dio/src/tracing_client_adapter.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_http_client_adapter.dart';

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

    test('HTTP GET creates spanv2 with correct attributes', () async {
      final dio = fixture.getDio(
        mockAdapter: fixture.getMockAdapter(
          statusCode: 200,
          responseBody: '{"success": true}',
        ),
      );

      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      await dio.get<dynamic>('/api/users');

      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      final span = fixture.processor.findSpanByOperation('http.client');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      expect(span.attributes[SemanticAttributesConstants.sentryOp]?.value, equals('http.client'));
      expect(span.attributes[SemanticAttributesConstants.httpRequestMethod]?.value, equals('GET'));
      expect(span.attributes[SemanticAttributesConstants.url]?.value, equals('https://example.com/api/users'));
      expect(span.attributes[SemanticAttributesConstants.httpResponseStatusCode]?.value, equals(200));
      expect(span.attributes[SemanticAttributesConstants.sentryOrigin]?.value, equals('auto.http.dio.http_client_adapter'));

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

      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      try {
        await dio.get<dynamic>('/api/users');
      } catch (_) {}

      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      final span = fixture.processor.findSpanByOperation('http.client');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);

      expect(span.status, equals(SentrySpanStatusV2.error));

      expect(span.attributes[SemanticAttributesConstants.sentryOp]?.value, equals('http.client'));
      expect(span.parentSpan, equals(transactionSpan));
    });
  });
}

class Fixture {
  late final Hub hub;
  late final SentryOptions options;
  late final FakeTelemetryProcessor processor;

  Fixture() {
    processor = FakeTelemetryProcessor();
    options = defaultTestOptions()
      ..tracesSampleRate = 1.0
      ..traceLifecycle = SentryTraceLifecycle.streaming
      ..telemetryProcessor = processor;
    hub = Hub(options);

    options.addIntegration(InstrumentationSpanFactorySetupIntegration());
    options.integrations.last.call(hub, options);
  }

  Dio getDio({required MockHttpClientAdapter mockAdapter}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    dio.httpClientAdapter = TracingClientAdapter(client: mockAdapter, hub: hub);
    return dio;
  }

  MockHttpClientAdapter getMockAdapter({
    required int statusCode,
    required String responseBody,
  }) {
    return MockHttpClientAdapter(
      (options, requestStream, cancelFuture) async {
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
      },
    );
  }

  void dispose() {
    processor.clear();
    hub.close();
  }
}
