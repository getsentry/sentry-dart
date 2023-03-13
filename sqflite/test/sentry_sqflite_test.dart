@TestOn('vm')

import 'package:sentry/sentry.dart';
import 'package:sentry_sqflite/sentry_sqflite.dart';
import 'package:sentry_sqflite/src/sentry_sqflite.dart';
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

      // using ffi for testing on vm
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      when(fixture.hub.options).thenReturn(fixture.options);
    });

    test('returns wrapped data base if performance enabled ', () async {
      fixture.options.tracesSampleRate = 1.0;
      final db =
          await openDatabaseWithSentry(inMemoryDatabasePath, hub: fixture.hub);

      expect(db is SentryDatabase, true);

      await db.close();
    });

    test('returns original data base if performance disabled ', () async {
      fixture.options.tracesSampleRate = null;
      final db =
          await openDatabaseWithSentry(inMemoryDatabasePath, hub: fixture.hub);

      expect(db is! SentryDatabase, true);

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
}
