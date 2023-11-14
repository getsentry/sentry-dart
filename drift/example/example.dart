import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_drift/sentry_drift.dart';

import 'database.dart';

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
  final tr = Sentry.startTransaction('drift', 'op', bindToScope: true);
  final executor = SentryQueryExecutor(
    () => NativeDatabase.memory(),
    databaseName: 'your_db_name',
  );
  final db = AppDatabase(executor);

  await db.into(db.todoItems).insert(
        TodoItemsCompanion.insert(
          title: 'This is a test thing',
          content: 'test',
        ),
      );

  final items = await db.select(db.todoItems).get();
  print(items);

  await db.close();
  // remove after

  await tr.finish(status: const SpanStatus.ok());
}
