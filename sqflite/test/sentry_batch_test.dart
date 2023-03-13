@TestOn('vm')

import 'package:sentry/sentry.dart';
import 'package:sentry_sqflite/sentry_sqflite.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite_dev.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'mocks/mocks.mocks.dart';
import 'utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('$SentryBatch', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);

      // using ffi for testing on vm
      sqfliteFfiInit();
      databaseFactory = SentrySqfliteDatabaseFactory(
        databaseFactory: databaseFactoryFfi,
        hub: fixture.hub,
      );
    });

    test('returns wrapped batch if performance enabled', () async {
      final db = await fixture.getDatabase();
      final batch = db.batch();

      expect(batch is SentryBatch, true);

      await db.close();
    });

    test('returns original batch if performance disabled', () async {
      fixture.options.tracesSampleRate = null;

      final db = await fixture.getDatabase();
      final batch = db.batch();

      expect(batch is! SentryBatch, true);

      await db.close();
    });

    test('creates insert span', () async {
      final db = await fixture.getDatabase();
      final batch = db.batch();

      batch.insert('Product', <String, Object?>{'title': 'Product 1'});

      await batch.commit();

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db');
      expect(
          span.context.description, 'INSERT INTO Product (title) VALUES (?)');

      await db.close();
    });

    test('creates raw insert span', () async {
      final db = await fixture.getDatabase();
      final batch = db.batch();

      batch.rawInsert('INSERT INTO Product (title) VALUES (?)', ['Product 1']);

      await batch.commit();

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db');
      expect(
          span.context.description, 'INSERT INTO Product (title) VALUES (?)');

      await db.close();
    });

    test('creates update span', () async {
      final db = await fixture.getDatabase();
      final batch = db.batch();

      batch.update('Product', <String, Object?>{'title': 'Product 1'});

      await batch.commit();

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db');
      expect(span.context.description, 'UPDATE Product SET title = ?');

      await db.close();
    });

    test('creates raw update span', () async {
      final db = await fixture.getDatabase();
      final batch = db.batch();

      batch.rawUpdate('UPDATE Product SET title = ?', ['Product 1']);

      await batch.commit();

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db');
      expect(span.context.description, 'UPDATE Product SET title = ?');

      await db.close();
    });

    test('creates delete span', () async {
      final db = await fixture.getDatabase();
      final batch = db.batch();

      batch.delete('Product');

      await batch.commit();

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db');
      expect(span.context.description, 'DELETE FROM Product');

      await db.close();
    });

    test('creates raw delete span', () async {
      final db = await fixture.getDatabase();
      final batch = db.batch();

      batch.rawDelete('DELETE FROM Product');

      await batch.commit();

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db');
      expect(span.context.description, 'DELETE FROM Product');

      await db.close();
    });

    test('creates execute span', () async {
      final db = await fixture.getDatabase();
      final batch = db.batch();

      batch.execute('DELETE FROM Product');

      await batch.commit();

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db');
      expect(span.context.description, 'DELETE FROM Product');

      await db.close();
    });

    test('creates query span', () async {
      final db = await fixture.getDatabase();
      final batch = db.batch();

      batch.query('Product');

      await batch.commit();

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db');
      expect(span.context.description, 'SELECT * FROM Product');

      await db.close();
    });

    test('creates raw query span', () async {
      final db = await fixture.getDatabase();
      final batch = db.batch();

      batch.rawQuery('SELECT * FROM Product');

      await batch.commit();

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db');
      expect(span.context.description, 'SELECT * FROM Product');

      await db.close();
    });

    test('creates span with batch description', () async {
      final db = await fixture.getDatabase();
      final batch = db.batch();

      batch.insert('Product', <String, Object?>{'title': 'Product 1'});
      batch.query('Product');

      await batch.commit();

      final span = fixture.tracer.children.last;

      final desc = '''INSERT INTO Product (title) VALUES (?)
SELECT * FROM Product''';

      expect(span.context.operation, 'db');
      expect(span.context.description, desc);

      await db.close();
    });

    test('creates span with batch description using apply', () async {
      final db = await fixture.getDatabase();
      final batch = db.batch();

      batch.insert('Product', <String, Object?>{'title': 'Product 1'});
      batch.query('Product');

      await batch.apply();

      final span = fixture.tracer.children.last;

      final desc = '''INSERT INTO Product (title) VALUES (?)
SELECT * FROM Product''';

      expect(span.context.operation, 'db');
      expect(span.context.description, desc);

      await db.close();
    });

    tearDown(() {
      databaseFactory = sqfliteDatabaseFactoryDefault;
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryOptions(dsn: fakeDsn)..tracesSampleRate = 1.0;
  final _context = SentryTransactionContext('name', 'operation');
  late final tracer = SentryTracer(_context, hub);

  Future<Database> getDatabase() async {
    final db = await openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE Product (
        id INTEGER PRIMARY KEY,
        title TEXT
      )''');
    return db;
  }
}
