<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

Sentry integration for `hive` package
===========

| package     | build                                                                                                                                                                                | pub                                                                                                  | likes                                                                                                | popularity                                                                                                     | pub points |
|-------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------| ------- |
| sentry_hive | [![build](https://github.com/getsentry/sentry-dart/actions/workflows/hive.yml/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-hive) | [![pub package](https://img.shields.io/pub/v/sentry_hive.svg)](https://pub.dev/packages/sentry_hive) | [![likes](https://img.shields.io/pub/likes/sentry_hive)](https://pub.dev/packages/sentry_hive/score) | [![popularity](https://img.shields.io/pub/popularity/sentry_hive)](https://pub.dev/packages/sentry_hive/score) | [![pub points](https://img.shields.io/pub/points/sentry_hive)](https://pub.dev/packages/sentry_hive/score)

Integration for the [`hive`](https://pub.dev/packages/hive) package.

#### Usage

- Sign up for a Sentry.io account and get a DSN at https://sentry.io.

- Follow the installing instructions on [pub.dev](https://pub.dev/packages/sentry/install).

- Initialize the Sentry SDK using the DSN issued by Sentry.io.

- Call...

```dart
import 'package:sentry/sentry.dart';
import 'package:hive/hive.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://example@sentry.io/add-your-dsn-here';
      options.tracesSampleRate = 1.0;
    },
    appRunner: () => runApp(YourApp()),
  );
}

Future<void> insertUser() async {
  // Use [SentryHive] where you would use [Hive]
  final appDir = await getApplicationDocumentsDirectory();
  SentryHive
    ..init(appDir.path)
    ..registerAdapter(PersonAdapter());

  var box = await SentryHive.openBox('testBox');

  var person = Person(
    name: 'Dave',
    age: 22,
  );

  await box.put('dave', person);

  print(box.get('dave')); // Dave: 22
}

@HiveType(typeId: 1)
class Person {
  Person({required this.name, required this.age});

  @HiveField(0)
  String name;

  @HiveField(1)
  int age;

  @override
  String toString() {
    return '$name: $age';
  }
}
```

#### Resources

* [![Flutter docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=flutter%20docs)](https://docs.sentry.io/platforms/flutter/)
* [![Dart docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=dart%20docs)](https://docs.sentry.io/platforms/dart/)
* [![Discussions](https://img.shields.io/github/discussions/getsentry/sentry-dart.svg)](https://github.com/getsentry/sentry-dart/discussions)
* [![Discord Chat](https://img.shields.io/discord/621778831602221064?logo=discord&logoColor=ffffff&color=7389D8)](https://discord.gg/PXa5Apfe7K)
* [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](https://stackoverflow.com/questions/tagged/sentry)
* [![Twitter Follow](https://img.shields.io/twitter/follow/getsentry?label=getsentry&style=social)](https://twitter.com/intent/follow?screen_name=getsentry)
