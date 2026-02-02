// ignore_for_file: invalid_use_of_internal_member
@TestOn('vm')
library;

import 'package:_sentry_testing/_sentry_testing.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/tracing/instrumentation/span_factory_integration.dart';
import 'package:sentry_drift/sentry_drift.dart';
import 'package:sqlite3/open.dart';
import 'package:test/test.dart';

import 'test_database.dart';
import 'utils/windows_helper.dart';

void main() {
  open.overrideFor(OperatingSystem.windows, openOnWindows);

  group('Drift SpanV2 Integration', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await fixture.setUp();
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('Insert operation creates spanv2 with correct attributes', () async {
      final db = fixture.db;

      // Start transaction span (root of this trace)
      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      // Execute insert operation
      await db.into(db.todoItems).insert(
            TodoItemsCompanion.insert(
              title: 'Test Task',
              content: 'Test content',
            ),
          );

      // End transaction span and wait for async processing
      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      // Verify data was inserted
      final result = await db.select(db.todoItems).get();
      expect(result.length, equals(1));
      expect(result.first.title, equals('Test Task'));

      // Assert child spans were created
      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      // Find the database operation span
      final span = fixture.processor.findSpanByOperation('db.sql.query');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      // Verify operation and attributes
      expect(span.attributes[SemanticAttributesConstants.sentryOp]?.value, equals('db.sql.query'));
      expect(span.attributes[SemanticAttributesConstants.dbSystem]?.value, equals('sqlite'));
      expect(span.attributes[SemanticAttributesConstants.sentryOrigin]?.value, equals('auto.db.drift'));

      // Verify parent-child relationship
      expect(span.parentSpan, equals(transactionSpan));
      expect(span.traceId, equals(transactionSpan.traceId));
      expect(span.spanId, isNot(equals(transactionSpan.spanId)));
    });

    test('Select operation creates spanv2', () async {
      final db = fixture.db;

      // Insert test data
      await db.into(db.todoItems).insert(
            TodoItemsCompanion.insert(
              title: 'Sample Task',
              content: 'Sample content',
            ),
          );

      // Start transaction span
      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      // Execute select operation
      final result = await db.select(db.todoItems).get();

      // End transaction span and wait for async processing
      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      // Verify result
      expect(result.length, equals(1));
      expect(result.first.title, equals('Sample Task'));

      // Assert child span was created
      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      // Find the database operation span
      final span = fixture.processor.findSpanByOperation('db.sql.query');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      // Verify basic attributes
      expect(span.attributes[SemanticAttributesConstants.sentryOp]?.value, equals('db.sql.query'));
      expect(span.attributes[SemanticAttributesConstants.dbSystem]?.value, equals('sqlite'));
      expect(span.parentSpan, equals(transactionSpan));
    });

    test('Update operation creates spanv2', () async {
      final db = fixture.db;

      // Insert test data
      await db.into(db.todoItems).insert(
            TodoItemsCompanion.insert(
              title: 'Old Title',
              content: 'Old content',
            ),
          );

      // Start transaction span
      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      // Execute update operation
      await (db.update(db.todoItems)
            ..where((tbl) => tbl.title.equals('Old Title')))
          .write(
        TodoItemsCompanion(
          title: Value('New Title'),
        ),
      );

      // End transaction span and wait for async processing
      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      // Verify data was updated
      final result = await db.select(db.todoItems).get();
      expect(result.first.title, equals('New Title'));

      // Assert child span was created
      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      // Find the database operation span
      final span = fixture.processor.findSpanByOperation('db.sql.query');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      // Verify attributes
      expect(span.attributes[SemanticAttributesConstants.sentryOp]?.value, equals('db.sql.query'));
      expect(span.attributes[SemanticAttributesConstants.dbSystem]?.value, equals('sqlite'));
      expect(span.parentSpan, equals(transactionSpan));
    });
  });
}

class Fixture {
  late final Hub hub;
  late final SentryOptions options;
  late final FakeTelemetryProcessor processor;
  late AppDatabase db;

  static const String dbName = 'test-db';

  Fixture() {
    processor = FakeTelemetryProcessor();
    options = defaultTestOptions()
      ..tracesSampleRate = 1.0
      ..traceLifecycle = SentryTraceLifecycle.streaming
      ..telemetryProcessor = processor;
    hub = Hub(options);

    // Set up the span factory integration for streaming mode
    options.addIntegration(InstrumentationSpanFactorySetupIntegration());
    options.integrations.last.call(hub, options);
  }

  Future<void> setUp() async {
    // Open database with Sentry wrapper
    final queryExecutor = NativeDatabase.memory();
    final sentryQueryInterceptor = SentryQueryInterceptor(
      databaseName: dbName,
      hub: hub,
    );
    db = AppDatabase(queryExecutor.interceptWith(sentryQueryInterceptor));
  }

  Future<void> tearDown() async {
    processor.clear();

    try {
      await db.close();
    } catch (e) {
      // Ignore errors during cleanup
    }

    await hub.close();
  }
}

SentryOptions defaultTestOptions() {
  return SentryOptions(dsn: 'https://abc@def.ingest.sentry.io/1234567')
    ..automatedTestMode = true;
}
