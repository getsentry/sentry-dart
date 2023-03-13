@TestOn('vm')

import 'package:sentry/sentry.dart';
import 'package:sentry_sqflite/sentry_sqflite.dart';
// import 'package:sentry_sqflite/src/sentry_sqflite.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_test/flutter_test.dart';
// import 'package:sqflite/sqflite_dev.dart';
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:mockito/mockito.dart';

import 'mocks/mocks.mocks.dart';
import 'utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('openDatabaseWithSentry', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();

      // using ffi for testing on vm
      // databaseFactory = databaseFactoryFfi;
      when(fixture.hub.options).thenReturn(SentryOptions(dsn: fakeDsn));
    });

    test('returns wrapped data base if performance enabled ', () async {
      final batch = MockBatch();
      final sut = fixture.getSut(batch);

      final context = SentryTransactionContext('name', 'op');
      final tracer = SentryTracer(context, fixture.hub);
      // fixture.hub.setSpan(tracer);

      sut.delete('myTable', where: 'myArg', whereArgs: ['myValue']);

      await sut.commit();

      final span = tracer.children.last;
      expect('db', span.context.operation);
      expect('DELETE FROM myTable WHERE myArg'.trimRight(), span.context.description);
    });

    // tearDown(() {
    //   databaseFactory = sqfliteDatabaseFactoryDefault;
    // });
  });
}

class Fixture {
  final hub = MockHub();

  SentryBatch getSut(Batch batch) {
    return SentryBatch(
      batch,
      hub: hub,
    );
  }
}
