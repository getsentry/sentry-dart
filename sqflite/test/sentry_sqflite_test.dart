@TestOn('vm')
library sqflite_test;

import 'package:sentry/sentry.dart';
import 'package:sentry_sqflite/sentry_sqflite.dart';
import 'package:sentry_sqflite/src/sentry_sqflite.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite_dev.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'mocks/mocks.mocks.dart';
import 'utils.dart';

import 'package:mockito/mockito.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('openDatabaseWithSentry', () {
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

    tearDown(() {
      databaseFactory = sqfliteDatabaseFactoryDefault;
    });

    test('returns wrapped data base if performance enabled', () async {
      final db =
          await openDatabaseWithSentry(inMemoryDatabasePath, hub: fixture.hub);

      expect(db is SentryDatabase, true);

      await db.close();
    });

    test('returns wrapped read only data base if performance enabled ',
        () async {
      final db = await openReadOnlyDatabaseWithSentry(
        inMemoryDatabasePath,
        hub: fixture.hub,
      );

      expect(db is SentryDatabase, true);

      await db.close();
    });

    tearDown(() {
      databaseFactory = sqfliteDatabaseFactoryDefault;
    });
  });

  group('openReadOnlyDatabaseWithSentry', () {
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

    test('returns wrapped data base if performance enabled', () async {
      final db = await openReadOnlyDatabaseWithSentry(
        inMemoryDatabasePath,
        hub: fixture.hub,
      );

      expect(db is SentryDatabase, true);

      await db.close();
    });

    test('creates db open span', () async {
      final db =
          await openDatabaseWithSentry(inMemoryDatabasePath, hub: fixture.hub);

      final span = fixture.tracer.children.last;

      expect(span.context.operation, SentryDatabase.dbOp);
      expect(span.context.description, 'Open DB: $inMemoryDatabasePath');
      expect(span.status, SpanStatus.ok());
      // ignore: invalid_use_of_internal_member
      expect(span.origin, SentryTraceOrigins.autoDbSqfliteOpenDatabase);
      expect((db as SentryDatabase).dbName, inMemoryDatabasePath);

      await db.close();
    });

    test('creates db open breadcrumb', () async {
      final db =
          await openDatabaseWithSentry(inMemoryDatabasePath, hub: fixture.hub);

      final breadcrumb = fixture.hub.scope.breadcrumbs.first;
      expect(breadcrumb.category, SentryDatabase.dbOp);
      expect(breadcrumb.message, 'Open DB: $inMemoryDatabasePath');
      expect(breadcrumb.data?['status'], 'ok');

      await db.close();
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryOptions(dsn: fakeDsn)..tracesSampleRate = 1.0;
  final _context = SentryTransactionContext('name', 'operation');
  late final tracer = SentryTracer(_context, hub);
  late final scope = Scope(options);
}
