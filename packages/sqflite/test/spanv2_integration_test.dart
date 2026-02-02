// ignore_for_file: invalid_use_of_internal_member
@TestOn('vm')
library;

import 'package:_sentry_testing/_sentry_testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/tracing/instrumentation/span_factory_integration.dart';
import 'package:sentry_sqflite/sentry_sqflite.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sqflite SpanV2 Integration', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await fixture.setUp();
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    test('Database.query() creates spanv2 with correct attributes', () async {
      final db = fixture.db;

      // Create test table and insert data
      await db.execute('''
        CREATE TABLE Test (
          id INTEGER PRIMARY KEY,
          name TEXT
        )
      ''');
      await db.insert('Test', {'name': 'John Doe'});

      // Start transaction span (root of this trace)
      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      // Execute query operation
      final result = await db.query('Test');

      // End transaction span and wait for async processing
      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      // Verify result
      expect(result.length, equals(1));
      expect(result.first['name'], equals('John Doe'));

      // Assert child span was created
      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      // Find the database operation span
      final span = fixture.processor.findSpanByOperation('db.sql.query');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      // Verify operation and attributes
      expect(span.attributes[SemanticAttributesConstants.sentryOp]?.value,
          equals('db.sql.query'));
      expect(span.attributes[SemanticAttributesConstants.dbSystem]?.value,
          equals('sqlite'));
      expect(span.attributes[SemanticAttributesConstants.sentryOrigin]?.value,
          equals('auto.db.sqflite.database'));

      // Verify parent-child relationship
      expect(span.parentSpan, equals(transactionSpan));
      expect(span.traceId, equals(transactionSpan.traceId));
      expect(span.spanId, isNot(equals(transactionSpan.spanId)));
    });

    test('Database.insert() creates spanv2', () async {
      final db = fixture.db;

      // Create test table
      await db.execute('''
        CREATE TABLE Test (
          id INTEGER PRIMARY KEY,
          name TEXT
        )
      ''');

      // Start transaction span
      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      // Execute insert operation
      await db.insert('Test', {'name': 'Jane Doe'});

      // End transaction span and wait for async processing
      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      // Verify data was inserted
      final result = await db.query('Test');
      expect(result.length, equals(1));

      // Assert child span was created
      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      // Find the database operation span
      final span = fixture.processor.findSpanByOperation('db.sql.query');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      // Verify basic attributes
      expect(span.attributes[SemanticAttributesConstants.sentryOp]?.value,
          equals('db.sql.query'));
      expect(span.attributes[SemanticAttributesConstants.dbSystem]?.value,
          equals('sqlite'));
      expect(span.parentSpan, equals(transactionSpan));
    });

    test('Database.transaction() creates spanv2', () async {
      final db = fixture.db;

      // Create test table
      await db.execute('''
        CREATE TABLE Test (
          id INTEGER PRIMARY KEY,
          name TEXT
        )
      ''');

      // Start transaction span
      final transactionSpan = fixture.hub.startSpan(
        'test-transaction',
        parentSpan: null,
      );

      // Execute transaction
      await db.transaction((txn) async {
        await txn.insert('Test', {'name': 'Alice'});
        await txn.insert('Test', {'name': 'Bob'});
      });

      // End transaction span and wait for async processing
      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      // Verify data was inserted
      final result = await db.query('Test');
      expect(result.length, equals(2));

      // Assert child span was created
      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      // Find the transaction operation span
      final span = fixture.processor.findSpanByOperation('db.sql.transaction');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      // Verify attributes
      expect(span.attributes[SemanticAttributesConstants.sentryOp]?.value,
          equals('db.sql.transaction'));
      expect(span.attributes[SemanticAttributesConstants.dbSystem]?.value,
          equals('sqlite'));
      expect(span.parentSpan, equals(transactionSpan));
    });
  });
}

class Fixture {
  late final Hub hub;
  late final SentryOptions options;
  late final FakeTelemetryProcessor processor;
  late Database db;

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
  }

  Future<void> setUp() async {
    // Initialize sqflite_ffi for testing on VM
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Open database with Sentry wrapper
    db = await SentrySqfliteDatabaseFactory(
      databaseFactory: databaseFactory,
      hub: hub,
    ).openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 1),
    );
  }

  Future<void> tearDown() async {
    processor.clear();

    try {
      if (db.isOpen) {
        await db.close();
      }
    } catch (e) {
      // Ignore errors during cleanup
    }

    await hub.close();
  }
}
