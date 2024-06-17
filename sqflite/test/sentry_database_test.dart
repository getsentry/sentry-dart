@TestOn('vm')
library sqflite_test;

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

  group('$SentryDatabase success', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.scope).thenReturn(fixture.scope);
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
      expect(span.status, SpanStatus.ok());
      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabase,
      );
    });

    test('creates close breadcrumb', () async {
      final db = await fixture.getSut();

      await db.close();

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.message, 'Close DB: $inMemoryDatabasePath');
      expect(breadcrumb.category, SentryDatabase.dbOp);
      expect(breadcrumb.type, 'query');
    });

    test('creates transaction span', () async {
      final db = await fixture.getSut();

      await db.transaction((txn) async {
        expect(txn is SentrySqfliteTransaction, true);
      });
      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db.sql.transaction');
      expect(span.context.description, 'Transaction DB: $inMemoryDatabasePath');
      expect(span.status, SpanStatus.ok());
      expect(span.data[SentryDatabase.dbSystemKey], SentryDatabase.dbSystem);
      expect(span.data[SentryDatabase.dbNameKey], inMemoryDatabasePath);
      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabase,
      );

      await db.close();
    });

    test('creates readTransaction span', () async {
      final db = await fixture.getSut();

      await db.readTransaction((txn) async {
        expect(txn is SentrySqfliteTransaction, true);
      });
      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db.sql.read_transaction');
      expect(span.context.description, 'Transaction DB: $inMemoryDatabasePath');
      expect(span.status, SpanStatus.ok());
      expect(span.data[SentryDatabase.dbSystemKey], SentryDatabase.dbSystem);
      expect(span.data[SentryDatabase.dbNameKey], inMemoryDatabasePath);
      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabase,
      );

      await db.close();
    });

    test('creates transaction breadcrumb', () async {
      final db = await fixture.getSut();

      await db.transaction((txn) async {
        expect(txn is SentrySqfliteTransaction, true);
      });

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.message, 'Transaction DB: $inMemoryDatabasePath');
      expect(breadcrumb.category, 'db.sql.transaction');
      expect(breadcrumb.data?['status'], 'ok');
      expect(
        breadcrumb.data?[SentryDatabase.dbSystemKey],
        SentryDatabase.dbSystem,
      );
      expect(breadcrumb.data?[SentryDatabase.dbNameKey], inMemoryDatabasePath);
      expect(breadcrumb.type, 'query');

      await db.close();
    });

    test('creates readTransaction breadcrumb', () async {
      final db = await fixture.getSut();

      await db.readTransaction((txn) async {
        expect(txn is SentrySqfliteTransaction, true);
      });

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.message, 'Transaction DB: $inMemoryDatabasePath');
      expect(breadcrumb.category, 'db.sql.read_transaction');
      expect(breadcrumb.data?['status'], 'ok');
      expect(
        breadcrumb.data?[SentryDatabase.dbSystemKey],
        SentryDatabase.dbSystem,
      );
      expect(breadcrumb.data?[SentryDatabase.dbNameKey], inMemoryDatabasePath);
      expect(breadcrumb.type, 'query');

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
      expect(insertSpan.status, SpanStatus.ok());
      expect(
        insertSpan.data[SentryDatabase.dbSystemKey],
        SentryDatabase.dbSystem,
      );
      expect(insertSpan.data[SentryDatabase.dbNameKey], inMemoryDatabasePath);

      expect(
        insertSpan.origin,
        // ignore: invalid_use_of_internal_member,
        SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      );

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

    test('opening db sets currentDbName with :memory:', () async {
      final db = await fixture.getSut();

      expect(db.dbName, ':memory:');

      await db.close();
    });

    test('opening db sets currentDbName with db file without extension',
        () async {
      final db = await fixture.getSut(
        database: await openDatabase('path/database/mydatabase.db'),
        execute: false,
      );

      expect(db.dbName, 'mydatabase');

      await db.close();
    });

    test('closing db sets currentDbName to null', () async {
      final db = await fixture.getSut();

      expect(db.dbName, inMemoryDatabasePath);

      await db.close();
    });

    tearDown(() {
      databaseFactory = sqfliteDatabaseFactoryDefault;
    });
  });

  group('$SentryDatabase fail', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.scope).thenReturn(fixture.scope);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);

      when(fixture.database.path).thenReturn('/path/db');
      when(fixture.database.execute(any)).thenAnswer((_) async => {});
    });

    test('close sets span to internal error', () async {
      when(fixture.database.close()).thenThrow(fixture.exception);

      final db = await fixture.getSut(database: fixture.database);

      await expectLater(() async => await db.close(), throwsException);

      final span = fixture.tracer.children.last;
      expect(span.throwable, fixture.exception);
      expect(span.status, SpanStatus.internalError());

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabase,
      );
    });

    test('close sets breadcrumb to internal error', () async {
      when(fixture.database.close()).thenThrow(fixture.exception);

      final db = await fixture.getSut(database: fixture.database);

      await expectLater(() async => await db.close(), throwsException);

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.data?['status'], 'internal_error');
      expect(breadcrumb.type, 'query');
      expect(breadcrumb.level, SentryLevel.warning);
    });

    test('transaction sets span to internal error', () async {
      // ignore: inference_failure_on_function_invocation
      when(fixture.database.transaction(any)).thenThrow(fixture.exception);

      final db = await fixture.getSut(database: fixture.database);

      await expectLater(
        () async => await db.transaction((txn) async {}),
        throwsException,
      );

      final span = fixture.tracer.children.last;
      expect(span.throwable, fixture.exception);
      expect(span.status, SpanStatus.internalError());

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabase,
      );
    });

    test('transaction sets breadcrumb to internal error', () async {
      // ignore: inference_failure_on_function_invocation
      when(fixture.database.transaction(any)).thenThrow(fixture.exception);

      final db = await fixture.getSut(database: fixture.database);

      await expectLater(
        () async => await db.transaction((txn) async {}),
        throwsException,
      );

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.data?['status'], 'internal_error');
      expect(breadcrumb.type, 'query');
      expect(breadcrumb.level, SentryLevel.warning);
    });
  });

  group('$SentryDatabaseExecutor success', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.scope).thenReturn(fixture.scope);
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
      expect(span.status, SpanStatus.ok());
      expect(span.data[SentryDatabase.dbSystemKey], SentryDatabase.dbSystem);
      expect(span.data[SentryDatabase.dbNameKey], inMemoryDatabasePath);

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      );

      await db.close();
    });

    test('creates delete breadcrumb', () async {
      final db = await fixture.getSut();

      await db.delete('Product');

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.category, 'db.sql.execute');
      expect(breadcrumb.message, 'DELETE FROM Product');
      expect(breadcrumb.data?['status'], 'ok');
      expect(
        breadcrumb.data?[SentryDatabase.dbSystemKey],
        SentryDatabase.dbSystem,
      );
      expect(breadcrumb.data?[SentryDatabase.dbNameKey], inMemoryDatabasePath);
      expect(breadcrumb.type, 'query');

      await db.close();
    });

    test('creates execute span', () async {
      final db = await fixture.getSut();

      await db.execute('DELETE FROM Product');

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db.sql.execute');
      expect(span.context.description, 'DELETE FROM Product');
      expect(span.status, SpanStatus.ok());
      expect(span.data[SentryDatabase.dbSystemKey], SentryDatabase.dbSystem);
      expect(span.data[SentryDatabase.dbNameKey], inMemoryDatabasePath);

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      );

      await db.close();
    });

    test('creates execute breadcrumb', () async {
      final db = await fixture.getSut();

      await db.execute('DELETE FROM Product');

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.category, 'db.sql.execute');
      expect(breadcrumb.message, 'DELETE FROM Product');
      expect(breadcrumb.data?['status'], 'ok');
      expect(
        breadcrumb.data?[SentryDatabase.dbSystemKey],
        SentryDatabase.dbSystem,
      );
      expect(breadcrumb.data?[SentryDatabase.dbNameKey], inMemoryDatabasePath);
      expect(breadcrumb.type, 'query');

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
      expect(span.status, SpanStatus.ok());
      expect(span.data[SentryDatabase.dbSystemKey], SentryDatabase.dbSystem);
      expect(span.data[SentryDatabase.dbNameKey], inMemoryDatabasePath);

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      );

      await db.close();
    });

    test('creates insert breadcrumb', () async {
      final db = await fixture.getSut();

      await db.insert('Product', <String, Object?>{'title': 'Product 1'});

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.category, 'db.sql.execute');
      expect(
        breadcrumb.message,
        'INSERT INTO Product (title) VALUES (?)',
      );
      expect(breadcrumb.data?['status'], 'ok');
      expect(
        breadcrumb.data?[SentryDatabase.dbSystemKey],
        SentryDatabase.dbSystem,
      );
      expect(breadcrumb.data?[SentryDatabase.dbNameKey], inMemoryDatabasePath);
      expect(breadcrumb.type, 'query');

      await db.close();
    });

    test('creates query span', () async {
      final db = await fixture.getSut();

      await db.query('Product');

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db.sql.query');
      expect(span.context.description, 'SELECT * FROM Product');
      expect(span.status, SpanStatus.ok());
      expect(span.data[SentryDatabase.dbSystemKey], SentryDatabase.dbSystem);
      expect(span.data[SentryDatabase.dbNameKey], inMemoryDatabasePath);

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      );

      await db.close();
    });

    test('creates query breadcrumb', () async {
      final db = await fixture.getSut();

      await db.query('Product');

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.category, 'db.sql.query');
      expect(breadcrumb.type, 'query');
      expect(breadcrumb.message, 'SELECT * FROM Product');
      expect(breadcrumb.data?['status'], 'ok');
      expect(
        breadcrumb.data?[SentryDatabase.dbSystemKey],
        SentryDatabase.dbSystem,
      );
      expect(breadcrumb.data?[SentryDatabase.dbNameKey], inMemoryDatabasePath);
      expect(breadcrumb.type, 'query');

      await db.close();
    });

    test('creates query cursor span', () async {
      final db = await fixture.getSut();

      await db.queryCursor('Product');

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db.sql.query');
      expect(span.context.description, 'SELECT * FROM Product');
      expect(span.status, SpanStatus.ok());
      expect(span.data[SentryDatabase.dbSystemKey], SentryDatabase.dbSystem);
      expect(span.data[SentryDatabase.dbNameKey], inMemoryDatabasePath);

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      );

      await db.close();
    });

    test('creates query cursor breadcrumb', () async {
      final db = await fixture.getSut();

      await db.queryCursor('Product');

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.category, 'db.sql.query');
      expect(breadcrumb.type, 'query');
      expect(breadcrumb.message, 'SELECT * FROM Product');
      expect(breadcrumb.data?['status'], 'ok');
      expect(
        breadcrumb.data?[SentryDatabase.dbSystemKey],
        SentryDatabase.dbSystem,
      );
      expect(breadcrumb.data?[SentryDatabase.dbNameKey], inMemoryDatabasePath);
      expect(breadcrumb.type, 'query');

      await db.close();
    });

    test('creates raw delete span', () async {
      final db = await fixture.getSut();

      await db.rawDelete('DELETE FROM Product');

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db.sql.execute');
      expect(span.context.description, 'DELETE FROM Product');
      expect(span.status, SpanStatus.ok());
      expect(span.data[SentryDatabase.dbSystemKey], SentryDatabase.dbSystem);
      expect(span.data[SentryDatabase.dbNameKey], inMemoryDatabasePath);

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      );

      await db.close();
    });

    test('creates raw delete breadcrumb', () async {
      final db = await fixture.getSut();

      await db.rawDelete('DELETE FROM Product');

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.category, 'db.sql.execute');
      expect(breadcrumb.message, 'DELETE FROM Product');
      expect(breadcrumb.data?['status'], 'ok');
      expect(
        breadcrumb.data?[SentryDatabase.dbSystemKey],
        SentryDatabase.dbSystem,
      );
      expect(breadcrumb.data?[SentryDatabase.dbNameKey], inMemoryDatabasePath);
      expect(breadcrumb.type, 'query');

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
      expect(span.status, SpanStatus.ok());
      expect(span.data[SentryDatabase.dbSystemKey], SentryDatabase.dbSystem);
      expect(span.data[SentryDatabase.dbNameKey], inMemoryDatabasePath);

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      );

      await db.close();
    });

    test('creates raw insert breadcrumb', () async {
      final db = await fixture.getSut();

      await db
          .rawInsert('INSERT INTO Product (title) VALUES (?)', ['Product 1']);

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.category, 'db.sql.execute');
      expect(breadcrumb.message, 'INSERT INTO Product (title) VALUES (?)');
      expect(breadcrumb.data?['status'], 'ok');
      expect(
        breadcrumb.data?[SentryDatabase.dbSystemKey],
        SentryDatabase.dbSystem,
      );
      expect(breadcrumb.data?[SentryDatabase.dbNameKey], inMemoryDatabasePath);
      expect(breadcrumb.type, 'query');

      await db.close();
    });

    test('creates raw query span', () async {
      final db = await fixture.getSut();

      await db.rawQuery('SELECT * FROM Product');

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db.sql.query');
      expect(span.context.description, 'SELECT * FROM Product');
      expect(span.status, SpanStatus.ok());
      expect(span.data[SentryDatabase.dbSystemKey], SentryDatabase.dbSystem);
      expect(span.data[SentryDatabase.dbNameKey], inMemoryDatabasePath);

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      );

      await db.close();
    });

    test('creates raw query breadcrumb', () async {
      final db = await fixture.getSut();

      await db.rawQuery('SELECT * FROM Product');

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.category, 'db.sql.query');
      expect(breadcrumb.type, 'query');
      expect(breadcrumb.message, 'SELECT * FROM Product');
      expect(breadcrumb.data?['status'], 'ok');
      expect(
        breadcrumb.data?[SentryDatabase.dbSystemKey],
        SentryDatabase.dbSystem,
      );
      expect(breadcrumb.data?[SentryDatabase.dbNameKey], inMemoryDatabasePath);
      expect(breadcrumb.type, 'query');

      await db.close();
    });

    test('creates raw query cursor span', () async {
      final db = await fixture.getSut();

      await db.rawQueryCursor('SELECT * FROM Product', []);

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db.sql.query');
      expect(span.context.description, 'SELECT * FROM Product');
      expect(span.status, SpanStatus.ok());
      expect(span.data[SentryDatabase.dbSystemKey], SentryDatabase.dbSystem);
      expect(span.data[SentryDatabase.dbNameKey], inMemoryDatabasePath);

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      );

      await db.close();
    });

    test('creates raw query cursor breadcrumb', () async {
      final db = await fixture.getSut();

      await db.rawQueryCursor('SELECT * FROM Product', []);

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.category, 'db.sql.query');
      expect(breadcrumb.type, 'query');
      expect(breadcrumb.message, 'SELECT * FROM Product');
      expect(breadcrumb.data?['status'], 'ok');
      expect(
        breadcrumb.data?[SentryDatabase.dbSystemKey],
        SentryDatabase.dbSystem,
      );
      expect(breadcrumb.data?[SentryDatabase.dbNameKey], inMemoryDatabasePath);
      expect(breadcrumb.type, 'query');

      await db.close();
    });

    test('creates raw update span', () async {
      final db = await fixture.getSut();

      await db.rawUpdate('UPDATE Product SET title = ?', ['Product 1']);

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db.sql.execute');
      expect(span.context.description, 'UPDATE Product SET title = ?');
      expect(span.status, SpanStatus.ok());
      expect(span.data[SentryDatabase.dbSystemKey], SentryDatabase.dbSystem);
      expect(span.data[SentryDatabase.dbNameKey], inMemoryDatabasePath);

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      );

      await db.close();
    });

    test('creates raw update breadcrumb', () async {
      final db = await fixture.getSut();

      await db.rawUpdate('UPDATE Product SET title = ?', ['Product 1']);

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.category, 'db.sql.execute');
      expect(breadcrumb.message, 'UPDATE Product SET title = ?');
      expect(breadcrumb.data?['status'], 'ok');
      expect(
        breadcrumb.data?[SentryDatabase.dbSystemKey],
        SentryDatabase.dbSystem,
      );
      expect(breadcrumb.data?[SentryDatabase.dbNameKey], inMemoryDatabasePath);
      expect(breadcrumb.type, 'query');

      await db.close();
    });

    test('creates update span', () async {
      final db = await fixture.getSut();

      await db.update('Product', <String, Object?>{'title': 'Product 1'});

      final span = fixture.tracer.children.last;
      expect(span.context.operation, 'db.sql.execute');
      expect(span.context.description, 'UPDATE Product SET title = ?');
      expect(span.status, SpanStatus.ok());
      expect(span.data[SentryDatabase.dbSystemKey], SentryDatabase.dbSystem);
      expect(span.data[SentryDatabase.dbNameKey], inMemoryDatabasePath);

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      );

      await db.close();
    });

    test('creates update breadcrumb', () async {
      final db = await fixture.getSut();

      await db.update('Product', <String, Object?>{'title': 'Product 1'});

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.category, 'db.sql.execute');
      expect(breadcrumb.message, 'UPDATE Product SET title = ?');
      expect(breadcrumb.data?['status'], 'ok');
      expect(
        breadcrumb.data?[SentryDatabase.dbSystemKey],
        SentryDatabase.dbSystem,
      );
      expect(breadcrumb.data?[SentryDatabase.dbNameKey], inMemoryDatabasePath);
      expect(breadcrumb.type, 'query');

      await db.close();
    });

    tearDown(() {
      databaseFactory = sqfliteDatabaseFactoryDefault;
    });
  });

  group('$SentryDatabaseExecutor fail', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();

      when(fixture.hub.options).thenReturn(fixture.options);
      when(fixture.hub.scope).thenReturn(fixture.scope);
      when(fixture.hub.getSpan()).thenReturn(fixture.tracer);
    });

    test('delete sets span to internal error', () async {
      when(fixture.executor.delete(any)).thenThrow(fixture.exception);

      final executor = fixture.getExecutorSut();

      await expectLater(
        () async => await executor.delete('Product'),
        throwsException,
      );

      final span = fixture.tracer.children.last;
      expect(span.throwable, fixture.exception);
      expect(span.status, SpanStatus.internalError());

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      );
    });

    test('execute sets span to internal error', () async {
      when(fixture.executor.execute(any)).thenThrow(fixture.exception);

      final executor = fixture.getExecutorSut();

      await expectLater(
        () async => await executor.execute('sql'),
        throwsException,
      );

      final span = fixture.tracer.children.last;
      expect(span.throwable, fixture.exception);
      expect(span.status, SpanStatus.internalError());

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      );
    });

    test('insert sets span to internal error', () async {
      when(fixture.executor.insert(any, any)).thenThrow(fixture.exception);

      final executor = fixture.getExecutorSut();

      await expectLater(
        () async => await executor
            .insert('Product', <String, Object?>{'title': 'Product 1'}),
        throwsException,
      );

      final span = fixture.tracer.children.last;
      expect(span.throwable, fixture.exception);
      expect(span.status, SpanStatus.internalError());

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      );
    });

    test('query sets span to internal error', () async {
      when(fixture.executor.query(any)).thenThrow(fixture.exception);

      final executor = fixture.getExecutorSut();

      await expectLater(
        () async => await executor.query('sql'),
        throwsException,
      );

      final span = fixture.tracer.children.last;
      expect(span.throwable, fixture.exception);
      expect(span.status, SpanStatus.internalError());

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      );
    });

    test('query cursor sets span to internal error', () async {
      when(fixture.executor.queryCursor(any)).thenThrow(fixture.exception);

      final executor = fixture.getExecutorSut();

      await expectLater(
        () async => await executor.queryCursor('sql'),
        throwsException,
      );

      final span = fixture.tracer.children.last;
      expect(span.throwable, fixture.exception);
      expect(span.status, SpanStatus.internalError());

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      );
    });

    test('raw delete sets span to internal error', () async {
      when(fixture.executor.rawDelete(any)).thenThrow(fixture.exception);

      final executor = fixture.getExecutorSut();

      await expectLater(
        () async => await executor.rawDelete('sql'),
        throwsException,
      );

      final span = fixture.tracer.children.last;
      expect(span.throwable, fixture.exception);
      expect(span.status, SpanStatus.internalError());

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      );
    });

    test('raw insert sets span to internal error', () async {
      when(fixture.executor.rawInsert(any)).thenThrow(fixture.exception);

      final executor = fixture.getExecutorSut();

      await expectLater(
        () async => await executor.rawInsert('sql'),
        throwsException,
      );

      final span = fixture.tracer.children.last;
      expect(span.throwable, fixture.exception);
      expect(span.status, SpanStatus.internalError());

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      );
    });

    test('raw query sets span to internal error', () async {
      when(fixture.executor.rawQuery(any)).thenThrow(fixture.exception);

      final executor = fixture.getExecutorSut();

      await expectLater(
        () async => await executor.rawQuery('sql'),
        throwsException,
      );

      final span = fixture.tracer.children.last;
      expect(span.throwable, fixture.exception);
      expect(span.status, SpanStatus.internalError());

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      );
    });

    test('raw query cursor sets span to internal error', () async {
      when(fixture.executor.rawQueryCursor(any, any))
          .thenThrow(fixture.exception);

      final executor = fixture.getExecutorSut();

      await expectLater(
        () async => await executor.rawQueryCursor('sql', []),
        throwsException,
      );

      final span = fixture.tracer.children.last;
      expect(span.throwable, fixture.exception);
      expect(span.status, SpanStatus.internalError());

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      );
    });

    test('raw update sets span to internal error', () async {
      when(fixture.executor.rawUpdate(any)).thenThrow(fixture.exception);

      final executor = fixture.getExecutorSut();

      await expectLater(
        () async => await executor.rawUpdate('sql'),
        throwsException,
      );

      final span = fixture.tracer.children.last;
      expect(span.throwable, fixture.exception);
      expect(span.status, SpanStatus.internalError());

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      );
    });

    test('update sets span to internal error', () async {
      when(fixture.executor.update(any, any)).thenThrow(fixture.exception);

      final executor = fixture.getExecutorSut();

      await expectLater(
        () async => await executor
            .update('Product', <String, Object?>{'title': 'Product 1'}),
        throwsException,
      );

      final span = fixture.tracer.children.last;
      expect(span.throwable, fixture.exception);
      expect(span.status, SpanStatus.internalError());

      expect(
        span.origin,
        // ignore: invalid_use_of_internal_member
        SentryTraceOrigins.autoDbSqfliteDatabaseExecutor,
      );
    });

    test('delete sets breadcrumb to internal error', () async {
      when(fixture.executor.delete(any)).thenThrow(fixture.exception);

      final executor = fixture.getExecutorSut();

      await expectLater(
        () async => await executor.delete('Product'),
        throwsException,
      );

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.data?['status'], 'internal_error');
      expect(breadcrumb.type, 'query');
      expect(breadcrumb.level, SentryLevel.warning);
    });

    test('execute sets breadcrumb to internal error', () async {
      when(fixture.executor.execute(any)).thenThrow(fixture.exception);

      final executor = fixture.getExecutorSut();

      await expectLater(
        () async => await executor.execute('sql'),
        throwsException,
      );

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.data?['status'], 'internal_error');
      expect(breadcrumb.type, 'query');
      expect(breadcrumb.level, SentryLevel.warning);
    });

    test('insert sets breadcrumb to internal error', () async {
      when(fixture.executor.insert(any, any)).thenThrow(fixture.exception);

      final executor = fixture.getExecutorSut();

      await expectLater(
        () async => await executor
            .insert('Product', <String, Object?>{'title': 'Product 1'}),
        throwsException,
      );

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.data?['status'], 'internal_error');
      expect(breadcrumb.type, 'query');
      expect(breadcrumb.level, SentryLevel.warning);
    });

    test('query sets breadcrumb to internal error', () async {
      when(fixture.executor.query(any)).thenThrow(fixture.exception);

      final executor = fixture.getExecutorSut();

      await expectLater(
        () async => await executor.query('sql'),
        throwsException,
      );

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.data?['status'], 'internal_error');
      expect(breadcrumb.type, 'query');
      expect(breadcrumb.level, SentryLevel.warning);
    });

    test('query cursor sets breadcrumb to internal error', () async {
      when(fixture.executor.queryCursor(any)).thenThrow(fixture.exception);

      final executor = fixture.getExecutorSut();

      await expectLater(
        () async => await executor.queryCursor('sql'),
        throwsException,
      );

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.data?['status'], 'internal_error');
      expect(breadcrumb.type, 'query');
      expect(breadcrumb.level, SentryLevel.warning);
    });

    test('raw delete sets breadcrumb to internal error', () async {
      when(fixture.executor.rawDelete(any)).thenThrow(fixture.exception);

      final executor = fixture.getExecutorSut();

      await expectLater(
        () async => await executor.rawDelete('sql'),
        throwsException,
      );

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.data?['status'], 'internal_error');
      expect(breadcrumb.type, 'query');
      expect(breadcrumb.level, SentryLevel.warning);
    });

    test('raw insert sets breadcrumb to internal error', () async {
      when(fixture.executor.rawInsert(any)).thenThrow(fixture.exception);

      final executor = fixture.getExecutorSut();

      await expectLater(
        () async => await executor.rawInsert('sql'),
        throwsException,
      );

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.data?['status'], 'internal_error');
      expect(breadcrumb.type, 'query');
      expect(breadcrumb.level, SentryLevel.warning);
    });

    test('raw query sets breadcrumb to internal error', () async {
      when(fixture.executor.rawQuery(any)).thenThrow(fixture.exception);

      final executor = fixture.getExecutorSut();

      await expectLater(
        () async => await executor.rawQuery('sql'),
        throwsException,
      );

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.data?['status'], 'internal_error');
      expect(breadcrumb.type, 'query');
      expect(breadcrumb.level, SentryLevel.warning);
    });

    test('raw query cursor sets breadcrumb to internal error', () async {
      when(fixture.executor.rawQueryCursor(any, any))
          .thenThrow(fixture.exception);

      final executor = fixture.getExecutorSut();

      await expectLater(
        () async => await executor.rawQueryCursor('sql', []),
        throwsException,
      );

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.data?['status'], 'internal_error');
      expect(breadcrumb.type, 'query');
      expect(breadcrumb.level, SentryLevel.warning);
    });

    test('raw update sets breadcrumb to internal error', () async {
      when(fixture.executor.rawUpdate(any)).thenThrow(fixture.exception);

      final executor = fixture.getExecutorSut();

      await expectLater(
        () async => await executor.rawUpdate('sql'),
        throwsException,
      );

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.data?['status'], 'internal_error');
      expect(breadcrumb.type, 'query');
      expect(breadcrumb.level, SentryLevel.warning);
    });

    test('update sets breadcrumb to internal error', () async {
      when(fixture.executor.update(any, any)).thenThrow(fixture.exception);

      final executor = fixture.getExecutorSut();

      await expectLater(
        () async => await executor
            .update('Product', <String, Object?>{'title': 'Product 1'}),
        throwsException,
      );

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.data?['status'], 'internal_error');
      expect(breadcrumb.type, 'query');
      expect(breadcrumb.level, SentryLevel.warning);
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryOptions(dsn: fakeDsn);
  final _context = SentryTransactionContext('name', 'operation');
  late final tracer = SentryTracer(_context, hub);
  final database = MockDatabase();
  final exception = Exception('error');
  final executor = MockDatabaseExecutor();
  late final scope = Scope(options);

  Future<SentryDatabase> getSut({
    double? tracesSampleRate = 1.0,
    Database? database,
    bool execute = true,
  }) async {
    options.tracesSampleRate = tracesSampleRate;
    final db = database ?? await openDatabase(inMemoryDatabasePath);
    if (execute) {
      await db.execute('''
      CREATE TABLE Product (
        id INTEGER PRIMARY KEY,
        title TEXT
      )''');
    }
    return SentryDatabase(db, hub: hub);
  }

  SentryDatabaseExecutor getExecutorSut() {
    return SentryDatabaseExecutor(executor, hub: hub);
  }
}
