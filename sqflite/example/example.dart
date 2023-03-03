import 'package:sentry/sentry.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

Future<void> main() async {
  // ATTENTION: Change the DSN below with your own to see the events in Sentry. Get one at sentry.io
  const dsn =
      'https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562';

  await Sentry.init(
    (options) {
      options.dsn = dsn;
      options.tracesSampleRate = 1.0;
      options.debug = true;
      options.sendDefaultPii = true;
    },
    appRunner: runApp, // Init your App.
  );
}

Future<void> runApp() async {
  sqfliteFfiInit();
  // final defaultFactory = databaseFactory;
  databaseFactory = SentrySqfliteDatabaseFactory(databaseFactoryFfi)

  var db = await openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE Product (
        id INTEGER PRIMARY KEY,
        title TEXT
      )
  ''');
    await db.insert('Product', <String, Object?>{'title': 'Product 1'});
    await db.insert('Product', <String, Object?>{'title': 'Product 2'});

    var result = await db.query('Product');
    expect(result, [
      {'id': 1, 'title': 'Product 1'},
      {'id': 2, 'title': 'Product 2'}
    ]);
    await db.close();
}
