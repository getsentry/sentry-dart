<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

Sentry integration for `isar` (community fork) package
===========

| package | build | pub | likes | popularity | pub points |
| ------- | ------- | ------- | ------- | ------- | ------- |
| sentry_isar_community | [![build](https://github.com/getsentry/sentry-dart/actions/workflows/isar_community.yml/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-isar-community) | [![pub package](https://img.shields.io/pub/v/sentry_isar_community.svg)](https://pub.dev/packages/sentry_isar_community) | [![likes](https://img.shields.io/pub/likes/sentry_isar_community)](https://pub.dev/packages/sentry_isar_community/score) | [![popularity](https://img.shields.io/pub/popularity/sentry_isar_community)](https://pub.dev/packages/sentry_isar_community/score) | [![pub points](https://img.shields.io/pub/points/sentry_isar_community)](https://pub.dev/packages/sentry_isar_community/score)

Integration for the [`isar` (community fork)](https://github.com/isar-community/isar) package.

#### Usage

- Sign up for a Sentry.io account and get a DSN at https://sentry.io.

- Follow the installing instructions on [pub.dev](https://pub.dev/packages/sentry/install).

- Initialize the Sentry SDK using the DSN issued by Sentry.io.

- Call...

```dart
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_isar_community/sentry_isar_community.dart';

import 'user.dart';

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

Future<void> runApp() async {
  final tr = Sentry.startTransaction(
    'isarTest',
    'db',
    bindToScope: true,
  );

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
```

#### Resources

* [![Flutter docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=flutter%20docs)](https://docs.sentry.io/platforms/flutter/)
* [![Dart docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=dart%20docs)](https://docs.sentry.io/platforms/dart/)
* [![Discussions](https://img.shields.io/github/discussions/getsentry/sentry-dart.svg)](https://github.com/getsentry/sentry-dart/discussions)
* [![Discord Chat](https://img.shields.io/discord/621778831602221064?logo=discord&logoColor=ffffff&color=7389D8)](https://discord.gg/PXa5Apfe7K)
* [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](https://stackoverflow.com/questions/tagged/sentry)
* [![Twitter Follow](https://img.shields.io/twitter/follow/getsentry?label=getsentry&style=social)](https://twitter.com/intent/follow?screen_name=getsentry)
