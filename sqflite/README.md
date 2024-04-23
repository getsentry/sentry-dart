<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

Sentry integration for `sqflite` package
===========

| package | build | pub | likes | popularity | pub points |
| ------- | ------- | ------- | ------- | ------- | ------- |
| sentry_sqflite | [![build](https://github.com/getsentry/sentry-dart/workflows/sentry-sqflite/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-sqflite) | [![pub package](https://img.shields.io/pub/v/sentry_sqflite.svg)](https://pub.dev/packages/sentry_sqflite) | [![likes](https://img.shields.io/pub/likes/sentry_sqflite)](https://pub.dev/packages/sentry_sqflite/score) | [![popularity](https://img.shields.io/pub/popularity/sentry_sqflite)](https://pub.dev/packages/sentry_sqflite/score) | [![pub points](https://img.shields.io/pub/points/sentry_sqflite)](https://pub.dev/packages/sentry_sqflite/score)

Integration for the [`sqflite`](https://pub.dev/packages/sqflite) package.

#### Usage

- Sign up for a Sentry.io account and get a DSN at https://sentry.io.

- Follow the installing instructions on [pub.dev](https://pub.dev/packages/sentry/install).

- Initialize the Sentry SDK using the DSN issued by Sentry.io.

- Call...

```dart
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sentry_sqflite/sentry_sqflite.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://example@sentry.io/add-your-dsn-here';
      options.tracesSampleRate = 1.0;
    },
    // Init your App.
    appRunner: () => runApp(MyApp()),
  );
}

Future<void> insertProducts() async {
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
```

#### Resources

* [![Flutter docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=flutter%20docs)](https://docs.sentry.io/platforms/flutter/)
* [![Dart docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=dart%20docs)](https://docs.sentry.io/platforms/dart/)
* [![Discussions](https://img.shields.io/github/discussions/getsentry/sentry-dart.svg)](https://github.com/getsentry/sentry-dart/discussions)
* [![Discord Chat](https://img.shields.io/discord/621778831602221064?logo=discord&logoColor=ffffff&color=7389D8)](https://discord.gg/PXa5Apfe7K)
* [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](https://stackoverflow.com/questions/tagged/sentry)
* [![Twitter Follow](https://img.shields.io/twitter/follow/getsentry?label=getsentry&style=social)](https://twitter.com/intent/follow?screen_name=getsentry)