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

      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      await db.into(db.todoItems).insert(
            TodoItemsCompanion.insert(
              title: 'Test Task',
              content: 'Test content',
            ),
          );

      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      final result = await db.select(db.todoItems).get();
      expect(result.length, equals(1));
      expect(result.first.title, equals('Test Task'));

      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      final span = fixture.processor.findSpanByOperation('db.sql.query');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      expect(span.attributes[SemanticAttributesConstants.sentryOp]?.value, equals('db.sql.query'));
      expect(span.attributes[SemanticAttributesConstants.dbSystem]?.value, equals('sqlite'));
      expect(span.attributes[SemanticAttributesConstants.sentryOrigin]?.value, equals('auto.db.drift'));

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

      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      final result = await db.select(db.todoItems).get();

      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      expect(result.length, equals(1));
      expect(result.first.title, equals('Sample Task'));

      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      final span = fixture.processor.findSpanByOperation('db.sql.query');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

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

      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      await (db.update(db.todoItems)
            ..where((tbl) => tbl.title.equals('Old Title')))
          .write(
        TodoItemsCompanion(
          title: Value('New Title'),
        ),
      );

      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      final result = await db.select(db.todoItems).get();
      expect(result.first.title, equals('New Title'));

      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      final span = fixture.processor.findSpanByOperation('db.sql.query');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

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
