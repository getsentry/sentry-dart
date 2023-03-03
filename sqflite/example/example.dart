import 'package:sentry/sentry.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sentry_sqflite/sentry_sqflite.dart';

Future<void> main() async {
  // ATTENTION: Change the DSN below with your own to see the events in Sentry. Get one at sentry.io
  const dsn =
      'https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562';

  await Sentry.init(
    (options) {
      options.dsn = dsn;
      options.tracesSampleRate = 1.0;
      options.debug = true;
    },
    appRunner: runApp, // Init your App.
  );
}

Future<void> runApp() async {
  databaseFactory = SentrySqfliteDatabaseFactory();

  final db = await openDatabase(inMemoryDatabasePath);
  await db.execute('''
      CREATE TABLE Product (
        id INTEGER PRIMARY KEY,
        title TEXT
      )
  ''');
  await db.insert('Product', <String, Object?>{'title': 'Product 1'});
  await db.insert('Product', <String, Object?>{'title': 'Product 2'});

  final result = await db.query('Product');
  print(result);

  await db.close();
}
