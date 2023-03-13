@TestOn('vm')

import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_sqflite/sentry_sqflite.dart';
import 'package:sentry_sqflite/src/sentry_database_executor.dart';
import 'package:sentry_sqflite/src/version.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite_dev.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'mocks/mocks.mocks.dart';

import 'package:mockito/mockito.dart';

import 'utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('$SentryDatabase', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);

      // using ffi for testing on vm
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('adds integration', () async {
      final db = await fixture.getSut();

      expect(
        fixture.options.sdk.integrations.contains('SentrySqfliteTracing'),
        true,
      );

      await db.close();
    });

    test('adds package', () async {
      final db = await fixture.getSut();

      expect(
        fixture.options.sdk.packages.any(
          (element) =>
              element.name == packageName && element.version == sdkVersion,
        ),
        true,
      );

      await db.close();
    });

    test('creates close span', () async {
      final db = await fixture.getSut();

      await db.close();

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db');
      expect(span.context.description, 'Close DB: $inMemoryDatabasePath');
    });

    test('creates transaction span', () async {
      final db = await fixture.getSut();

      await db.transaction((txn) async {
        expect(txn is SentrySqfliteTransaction, true);
      });
      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db.sql.transaction');
      expect(span.context.description, 'Transaction DB: $inMemoryDatabasePath');

      await db.close();
    });

    test('creates transaction children run by the transaction', () async {
      final db = await fixture.getSut();

      await db.transaction((txn) async {
        await txn.insert('Product', <String, Object?>{'title': 'Product 1'});
      });
      final trSpan = fixture.tracer.children.first;
      final insertSpan = fixture.tracer.children.last;

      expect(insertSpan.context.operation, 'db.sql.execute');
      expect(
        insertSpan.context.description,
        'INSERT INTO Product (title) VALUES (?)',
      );
      expect(insertSpan.context.parentSpanId, trSpan.context.spanId);

      await db.close();
    });

    test('transaction batch returns wrapped sentry batch', () async {
      final db = await fixture.getSut();

      await db.transaction((txn) async {
        final batch = txn.batch();
        expect(batch is SentryBatch, true);
      });

      await db.close();
    });

    tearDown(() {
      databaseFactory = sqfliteDatabaseFactoryDefault;
    });
  });

  group('$SentryDatabaseExecutor', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);

      // using ffi for testing on vm
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('creates delete span', () async {
      final db = await fixture.getSut();

      await db.delete('Product');

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db.sql.execute');
      expect(span.context.description, 'DELETE FROM Product');

      await db.close();
    });

    test('creates execute span', () async {
      final db = await fixture.getSut();

      await db.execute('DELETE FROM Product');

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db.sql.execute');
      expect(span.context.description, 'DELETE FROM Product');

      await db.close();
    });

    test('creates insert span', () async {
      final db = await fixture.getSut();

      await db.insert('Product', <String, Object?>{'title': 'Product 1'});

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db.sql.execute');
      expect(
        span.context.description,
        'INSERT INTO Product (title) VALUES (?)',
      );

      await db.close();
    });

    test('creates query span', () async {
      final db = await fixture.getSut();

      await db.query('Product');

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db.sql.query');
      expect(span.context.description, 'SELECT * FROM Product');

      await db.close();
    });

    test('creates query cursor span', () async {
      final db = await fixture.getSut();

      await db.queryCursor('Product');

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db.sql.query');
      expect(span.context.description, 'SELECT * FROM Product');

      await db.close();
    });

    test('creates raw delete span', () async {
      final db = await fixture.getSut();

      await db.rawDelete('DELETE FROM Product');

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db.sql.execute');
      expect(span.context.description, 'DELETE FROM Product');

      await db.close();
    });

    test('creates raw insert span', () async {
      final db = await fixture.getSut();

      await db
          .rawInsert('INSERT INTO Product (title) VALUES (?)', ['Product 1']);

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db.sql.execute');
      expect(
        span.context.description,
        'INSERT INTO Product (title) VALUES (?)',
      );

      await db.close();
    });

    test('creates raw query span', () async {
      final db = await fixture.getSut();

      await db.rawQuery('SELECT * FROM Product');

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db.sql.query');
      expect(span.context.description, 'SELECT * FROM Product');

      await db.close();
    });

    test('creates raw query cursor span', () async {
      final db = await fixture.getSut();

      await db.rawQueryCursor('SELECT * FROM Product', []);

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db.sql.query');
      expect(span.context.description, 'SELECT * FROM Product');

      await db.close();
    });

    test('creates raw update span', () async {
      final db = await fixture.getSut();

      await db.rawUpdate('UPDATE Product SET title = ?', ['Product 1']);

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db.sql.execute');
      expect(span.context.description, 'UPDATE Product SET title = ?');

      await db.close();
    });

    test('creates update span', () async {
      final db = await fixture.getSut();

      await db.update('Product', <String, Object?>{'title': 'Product 1'});

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db.sql.execute');
      expect(span.context.description, 'UPDATE Product SET title = ?');

      await db.close();
    });

    tearDown(() {
      databaseFactory = sqfliteDatabaseFactoryDefault;
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryOptions(dsn: fakeDsn);
  final _context = SentryTransactionContext('name', 'operation');
  late final tracer = SentryTracer(_context, hub);

  Future<SentryDatabase> getSut({
    double? tracesSampleRate = 1.0,
  }) async {
    options.tracesSampleRate = tracesSampleRate;
    final db = await openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE Product (
        id INTEGER PRIMARY KEY,
        title TEXT
      )''');
    return SentryDatabase(db, hub: hub);
  }
}
