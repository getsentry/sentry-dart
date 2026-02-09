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

    test('Database.query() creates spanv2', () async {
      final db = fixture.db;

      await db.execute('''
        CREATE TABLE Test (
          id INTEGER PRIMARY KEY,
          name TEXT
        )
      ''');
      await db.insert('Test', {'name': 'John Doe'});

      final transactionSpan = fixture.hub.startInactiveSpan(
        'test-transaction',
        parentSpan: null,
      );

      final result = await db.query('Test');

      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      expect(result.length, equals(1));
      expect(result.first['name'], equals('John Doe'));

      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      final span = fixture.processor.findSpanByOperation('db.sql.query');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      expect(
        span.attributes[SemanticAttributesConstants.sentryOp]?.value,
        equals('db.sql.query'),
      );
      expect(
        span.attributes[SemanticAttributesConstants.dbSystem]?.value,
        equals('sqlite'),
      );
      expect(
        span.attributes[SemanticAttributesConstants.sentryOrigin]?.value,
        equals('auto.db.sqflite.database_executor'),
      );

      expect(span.parentSpan, equals(transactionSpan));
      expect(span.traceId, equals(transactionSpan.traceId));
      expect(span.spanId, isNot(equals(transactionSpan.spanId)));
    });

    test('Database.insert() creates spanv2', () async {
      final db = fixture.db;

      await db.execute('''
        CREATE TABLE Test (
          id INTEGER PRIMARY KEY,
          name TEXT
        )
      ''');

      final transactionSpan = fixture.hub.startInactiveSpan(
        'test-transaction',
        parentSpan: null,
      );

      await db.insert('Test', {'name': 'Jane Doe'});

      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      final result = await db.query('Test');
      expect(result.length, equals(1));

      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      final span = fixture.processor.findSpanByOperation('db.sql.execute');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      expect(
        span.attributes[SemanticAttributesConstants.sentryOp]?.value,
        equals('db.sql.execute'),
      );
      expect(
        span.attributes[SemanticAttributesConstants.dbSystem]?.value,
        equals('sqlite'),
      );
      expect(span.parentSpan, equals(transactionSpan));
    });

    test('Database.transaction() creates spanv2', () async {
      final db = fixture.db;

      await db.execute('''
        CREATE TABLE Test (
          id INTEGER PRIMARY KEY,
          name TEXT
        )
      ''');

      final transactionSpan = fixture.hub.startInactiveSpan(
        'test-transaction',
        parentSpan: null,
      );

      await db.transaction((txn) async {
        await txn.insert('Test', {'name': 'Alice'});
        await txn.insert('Test', {'name': 'Bob'});
      });

      transactionSpan.end();
      await fixture.processor.waitForProcessing();

      final result = await db.query('Test');
      expect(result.length, equals(2));

      final childSpans = fixture.processor.getChildSpans();
      expect(childSpans.length, greaterThan(0));

      final span = fixture.processor.findSpanByOperation('db.sql.transaction');
      expect(span, isNotNull);
      expect(span!.isEnded, isTrue);
      expect(span.status, equals(SentrySpanStatusV2.ok));

      expect(
        span.attributes[SemanticAttributesConstants.sentryOp]?.value,
        equals('db.sql.transaction'),
      );
      expect(
        span.attributes[SemanticAttributesConstants.dbSystem]?.value,
        equals('sqlite'),
      );
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

    options.addIntegration(InstrumentationSpanFactorySetupIntegration());
    options.integrations.last.call(hub, options);
  }

  Future<void> setUp() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

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
