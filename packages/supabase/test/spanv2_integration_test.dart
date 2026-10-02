// ignore_for_file: invalid_use_of_internal_member, experimental_member_use
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

    test('Select operation creates spanv2', () async {
      final client = fixture.client;

      late SentrySpanV2 transactionSpan;
      await fixture.hub.startSpan(
        'test-transaction',
        (span) async {
          transactionSpan = span;
          try {
            await client.from('users').select().eq('id', 1);
          } catch (e) {
            // Ignore errors from mock HTTP requests
          }
        },
        parentSpan: null,
      );

      await fixture.processor.waitForProcessing();

      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      final span = fixture.processor.findSpanByOperation('db.select');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      expect(
        span.attributes[SemanticAttributesConstants.sentryOp]?.value,
        equals('db.select'),
      );
      expect(
        span.attributes[SemanticAttributesConstants.dbSystem]?.value,
        equals('postgresql'),
      );
      expect(
        span.attributes[SemanticAttributesConstants.sentryOrigin]?.value,
        equals('auto.db.supabase'),
      );

      expect(span.parentSpan, equals(transactionSpan));
      expect(span.traceId, equals(transactionSpan.traceId));
      expect(span.spanId, isNot(equals(transactionSpan.spanId)));
    });

    test('Insert operation creates spanv2', () async {
      final client = fixture.client;

      late SentrySpanV2 transactionSpan;
      await fixture.hub.startSpan(
        'test-transaction',
        (span) async {
          transactionSpan = span;
          try {
            await client
                .from('users')
                .insert({'name': 'John Doe', 'email': 'john@example.com'});
          } catch (e) {
            // Ignore errors from mock HTTP requests
          }
        },
        parentSpan: null,
      );

      await fixture.processor.waitForProcessing();

      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      final span = fixture.processor.findSpanByOperation('db.insert');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      expect(
        span.attributes[SemanticAttributesConstants.sentryOp]?.value,
        equals('db.insert'),
      );
      expect(
        span.attributes[SemanticAttributesConstants.dbSystem]?.value,
        equals('postgresql'),
      );
      expect(span.parentSpan, equals(transactionSpan));
    });

    test('Update operation creates spanv2', () async {
      final client = fixture.client;

      late SentrySpanV2 transactionSpan;
      await fixture.hub.startSpan(
        'test-transaction',
        (span) async {
          transactionSpan = span;
          try {
            await client.from('users').update({'name': 'Jane Doe'}).eq('id', 1);
          } catch (e) {
            // Ignore errors from mock HTTP requests
          }
        },
        parentSpan: null,
      );

      await fixture.processor.waitForProcessing();

      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      final span = fixture.processor.findSpanByOperation('db.update');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      expect(
        span.attributes[SemanticAttributesConstants.sentryOp]?.value,
        equals('db.update'),
      );
      expect(
        span.attributes[SemanticAttributesConstants.dbSystem]?.value,
        equals('postgresql'),
      );
      expect(span.parentSpan, equals(transactionSpan));
    });

    test('Delete operation creates spanv2', () async {
      final client = fixture.client;

      late SentrySpanV2 transactionSpan;
      await fixture.hub.startSpan(
        'test-transaction',
        (span) async {
          transactionSpan = span;
          try {
            await client.from('users').delete().eq('id', 1);
          } catch (e) {
            // Ignore errors from mock HTTP requests
          }
        },
        parentSpan: null,
      );

      await fixture.processor.waitForProcessing();

      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      final span = fixture.processor.findSpanByOperation('db.delete');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      expect(
        span.attributes[SemanticAttributesConstants.sentryOp]?.value,
        equals('db.delete'),
      );
      expect(
        span.attributes[SemanticAttributesConstants.dbSystem]?.value,
        equals('postgresql'),
      );
      expect(span.parentSpan, equals(transactionSpan));
    });

    group('when a failed request is captured', () {
      test('links the error to the db span', () async {
        fixture.mockHttpClient.statusCode = 500;

        late SentrySpanV2 transactionSpan;
        await fixture.hub.startSpan(
          'test-transaction',
          (span) async {
            transactionSpan = span;
            try {
              await fixture.client.from('users').select().eq('id', 1);
            } catch (_) {}
          },
          parentSpan: null,
        );

        await fixture.processor.waitForProcessing();
        await pumpEventQueue();
        final dbSpan = fixture.processor.findSpanByOperation('db.select')!;

        final traceContext = fixture.capturedEvents.first.contexts.trace;
        expect(traceContext?.spanId, dbSpan.spanId);
        expect(traceContext?.parentSpanId, transactionSpan.spanId);
        expect(traceContext?.traceId, transactionSpan.traceId);
        expect(traceContext?.operation, 'db.select');
      });

      test('does not link the error when no span is active', () async {
        fixture.mockHttpClient.statusCode = 500;

        try {
          await fixture.client.from('users').select().eq('id', 1);
        } catch (_) {}
        await pumpEventQueue();

        expect(fixture.processor.findSpanByOperation('db.select'), isNull);
        expect(
          fixture.capturedEvents.first.contexts.trace?.parentSpanId,
          isNull,
        );
      });
    });
  });
}

class Fixture {
  late final Hub hub;
  late final SentryOptions options;
  late final FakeTelemetryProcessor processor;
  late final SupabaseClient client;
  late final MockHttpClient mockHttpClient;
  final capturedEvents = <SentryEvent>[];

  Fixture() {
    processor = FakeTelemetryProcessor();
    options = SentryOptions(dsn: 'https://abc@def.ingest.sentry.io/1234567')
      ..automatedTestMode = true
      ..tracesSampleRate = 1.0
      ..traceLifecycle = SentryTraceLifecycle.stream
      ..telemetryProcessor = processor
      // Records the event after the scope was applied and drops it, so no
      // transport is involved.
      ..beforeSend = (event, hint) {
        capturedEvents.add(event);
        return null;
      };
    hub = Hub(options);

    options.addIntegration(InstrumentationSpanFactorySetupIntegration());
    options.integrations.last.call(hub, options);

    mockHttpClient = MockHttpClient();
  }

  Future<void> setUp() async {
    client = SupabaseClient(
      'https://test.supabase.co',
      'test-api-key',
      httpClient: SentrySupabaseClient(client: mockHttpClient, hub: hub),
    );
  }

  Future<void> tearDown() async {
    processor.clear();
    capturedEvents.clear();
    await hub.close();
  }
}

class MockHttpClient extends BaseClient {
  int statusCode = 200;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    return StreamedResponse(
      Stream.fromIterable([]),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  }
}
