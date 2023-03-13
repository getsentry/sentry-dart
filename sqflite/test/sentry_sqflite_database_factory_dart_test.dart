@TestOn('vm')

import 'package:sentry/sentry.dart';
import 'package:sentry_sqflite/sentry_sqflite.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite_dev.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'mocks/mocks.mocks.dart';

import 'package:mockito/mockito.dart';

import 'utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('openDatabaseWithSentry', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();

      // using ffi for testing on vm
      sqfliteFfiInit();
      databaseFactory = SentrySqfliteDatabaseFactory(
        databaseFactory: databaseFactoryFfi,
        hub: fixture.hub,
      );

      when(fixture.hub.options).thenReturn(fixture.options);
    });

    test('returns wrapped data base if performance enabled ', () async {
      fixture.options.tracesSampleRate = 1.0;

      final db = await openDatabase(inMemoryDatabasePath);

      expect(db is SentryDatabase, true);

      await db.close();
    });

    test('returns original data base if performance disabled ', () async {
      final db = await openDatabase(inMemoryDatabasePath);

      expect(db is! SentryDatabase, true);

      await db.close();
    });
  });

  tearDown(() {
    databaseFactory = sqfliteDatabaseFactoryDefault;
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryOptions(dsn: fakeDsn);
}
