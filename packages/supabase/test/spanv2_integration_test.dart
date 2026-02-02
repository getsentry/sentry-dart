// ignore_for_file: invalid_use_of_internal_member
@TestOn('vm')
library;

import 'package:_sentry_testing/_sentry_testing.dart';
import 'package:http/http.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/tracing/instrumentation/span_factory_integration.dart';
import 'package:sentry_supabase/sentry_supabase.dart';
import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

void main() {
  group('Supabase SpanV2 Integration', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await fixture.setUp();
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('Select operation creates spanv2 with correct attributes', () async {
      final client = fixture.client;

      // Start transaction span (root of this trace)
      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      // Execute select operation
      try {
        await client.from('users').select().eq('id', 1);
      } catch (e) {
        // Ignore errors from mock HTTP requests
      }

      // End transaction span and wait for async processing
      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      // Assert child span was created
      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      // Find the database operation span
      final span = fixture.processor.findSpanByOperation('db.select');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      // Verify operation and attributes
      expect(span.attributes[SemanticAttributesConstants.sentryOp]?.value, equals('db.select'));
      expect(span.attributes[SemanticAttributesConstants.dbSystem]?.value, equals('postgresql'));
      expect(span.attributes[SemanticAttributesConstants.sentryOrigin]?.value, equals('auto.db.supabase'));

      // Verify parent-child relationship
      expect(span.parentSpan, equals(transactionSpan));
      expect(span.traceId, equals(transactionSpan.traceId));
      expect(span.spanId, isNot(equals(transactionSpan.spanId)));
    });

    test('Insert operation creates spanv2', () async {
      final client = fixture.client;

      // Start transaction span
      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      // Execute insert operation
      try {
        await client.from('users').insert({'name': 'John Doe', 'email': 'john@example.com'});
      } catch (e) {
        // Ignore errors from mock HTTP requests
      }

      // End transaction span and wait for async processing
      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      // Assert child span was created
      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      // Find the database operation span
      final span = fixture.processor.findSpanByOperation('db.insert');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      // Verify basic attributes
      expect(span.attributes[SemanticAttributesConstants.sentryOp]?.value, equals('db.insert'));
      expect(span.attributes[SemanticAttributesConstants.dbSystem]?.value, equals('postgresql'));
      expect(span.parentSpan, equals(transactionSpan));
    });

    test('Update operation creates spanv2', () async {
      final client = fixture.client;

      // Start transaction span
      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      // Execute update operation
      try {
        await client.from('users').update({'name': 'Jane Doe'}).eq('id', 1);
      } catch (e) {
        // Ignore errors from mock HTTP requests
      }

      // End transaction span and wait for async processing
      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      // Assert child span was created
      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      // Find the database operation span
      final span = fixture.processor.findSpanByOperation('db.update');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      // Verify attributes
      expect(span.attributes[SemanticAttributesConstants.sentryOp]?.value, equals('db.update'));
      expect(span.attributes[SemanticAttributesConstants.dbSystem]?.value, equals('postgresql'));
      expect(span.parentSpan, equals(transactionSpan));
    });

    test('Delete operation creates spanv2', () async {
      final client = fixture.client;

      // Start transaction span
      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      // Execute delete operation
      try {
        await client.from('users').delete().eq('id', 1);
      } catch (e) {
        // Ignore errors from mock HTTP requests
      }

      // End transaction span and wait for async processing
      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      // Assert child span was created
      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      // Find the database operation span
      final span = fixture.processor.findSpanByOperation('db.delete');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      // Verify attributes
      expect(span.attributes[SemanticAttributesConstants.sentryOp]?.value, equals('db.delete'));
      expect(span.attributes[SemanticAttributesConstants.dbSystem]?.value, equals('postgresql'));
      expect(span.parentSpan, equals(transactionSpan));
    });
  });
}

class Fixture {
  late final Hub hub;
  late final SentryOptions options;
  late final FakeTelemetryProcessor processor;
  late final SupabaseClient client;
  late final MockHttpClient mockHttpClient;

  Fixture() {
    processor = FakeTelemetryProcessor();
    options = SentryOptions(dsn: 'https://abc@def.ingest.sentry.io/1234567')
      ..automatedTestMode = true
      ..tracesSampleRate = 1.0
      ..traceLifecycle = SentryTraceLifecycle.streaming
      ..telemetryProcessor = processor;
    hub = Hub(options);

    // Set up the span factory integration for streaming mode
    options.addIntegration(InstrumentationSpanFactorySetupIntegration());
    options.integrations.last.call(hub, options);

    // Create mock HTTP client
    mockHttpClient = MockHttpClient();
  }

  Future<void> setUp() async {
    // Create Supabase client with Sentry wrapper
    client = SupabaseClient(
      'https://test.supabase.co',
      'test-api-key',
      httpClient: SentrySupabaseClient(mockHttpClient, hub: hub),
    );
  }

  Future<void> tearDown() async {
    processor.clear();
    await hub.close();
  }
}

class MockHttpClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    // Return a mock response
    return StreamedResponse(
      Stream.fromIterable([]),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}
