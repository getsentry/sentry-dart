import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_isar/sentry_isar.dart';

import 'user.dart';

Future<void> main() async {
  // ATTENTION: Change the DSN below with your own to see the events in Sentry. Get one at sentry.io
  const dsn =
      'https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562';

  await SentryFlutter.init(
    (options) {
      options.dsn = dsn;
      options.tracesSampleRate = 1.0;
      options.debug = true;
    },
    appRunner: runApp, // Init your App.
  );
}

Future<void> runApp() async {
  final tr = Sentry.startTransaction('isar', 'db', bindToScope: true);

  final dir = await getApplicationDocumentsDirectory();

  final isar = await SentryIsar.open(
    [UserSchema],
    directory: dir.path,
  );

  final newUser = User()
    ..name = 'Joe Dirt'
    ..age = 36;

  await isar.writeTxn(() async {
    await isar.users.put(newUser); // insert & update
  });

  final existingUser = await isar.users.get(newUser.id); // get

  await isar.writeTxn(() async {
    await isar.users.delete(existingUser!.id); // delete
  });

  await tr.finish(status: const SpanStatus.ok());
}
