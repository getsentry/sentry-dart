<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

Sentry integration for `drift` package
===========

| package     | build                                                                                                                                                                             | pub                                                                                                  | likes                                                                                                | popularity                                                                                                     | pub points |
|-------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------| ------- |
| sentry_drift | [![build](https://github.com/getsentry/sentry-dart/actions/workflows/drift.yml/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-drift) | [![pub package](https://img.shields.io/pub/v/sentry_drift.svg)](https://pub.dev/packages/sentry_drift) | [![likes](https://img.shields.io/pub/likes/sentry_drift)](https://pub.dev/packages/sentry_drift/score) | [![popularity](https://img.shields.io/pub/popularity/sentry_drift)](https://pub.dev/packages/sentry_drift/score) | [![pub points](https://img.shields.io/pub/points/sentry_drift)](https://pub.dev/packages/sentry_drift/score)

Integration for the [`drift`](https://pub.dev/packages/drift) package.

#### Usage

- Sign up for a Sentry.io account and get a DSN at https://sentry.io.

- Follow the installing instructions on [pub.dev](https://pub.dev/packages/sentry/install).

- Initialize the Sentry SDK using the DSN issued by Sentry.io.

- Call...

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_drift/sentry_drift.dart';

import 'your_database.dart';

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
  final tr =
      Sentry.startTransaction('drift', 'op', bindToScope: true);
  final executor = SentryQueryExecutor(
    () => NativeDatabase.memory(),
    databaseName: 'my_db_name',
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

  await tr.finish(status: const SpanStatus.ok());
}
```

#### Resources

* [![Flutter docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=flutter%20docs)](https://docs.sentry.io/platforms/flutter/)
* [![Dart docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=dart%20docs)](https://docs.sentry.io/platforms/dart/)
* [![Discussions](https://img.shields.io/github/discussions/getsentry/sentry-dart.svg)](https://github.com/getsentry/sentry-dart/discussions)
* [![Discord Chat](https://img.shields.io/discord/621778831602221064?logo=discord&logoColor=ffffff&color=7389D8)](https://discord.gg/PXa5Apfe7K)
* [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](https://stackoverflow.com/questions/tagged/sentry)
* [![Twitter Follow](https://img.shields.io/twitter/follow/getsentry?label=getsentry&style=social)](https://twitter.com/intent/follow?screen_name=getsentry)
