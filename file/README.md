<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

Sentry integration for `dart.io.File`
===========

| package | build | pub | likes | popularity | pub points |
| ------- | ------- | ------- | ------- | ------- | ------- |
| sentry_file | [![build](https://github.com/getsentry/sentry-dart/workflows/sentry-file/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-file) | [![pub package](https://img.shields.io/pub/v/sentry_file.svg)](https://pub.dev/packages/sentry_file) | [![likes](https://img.shields.io/pub/likes/sentry_file)](https://pub.dev/packages/sentry_file/score) | [![popularity](https://img.shields.io/pub/popularity/sentry_file)](https://pub.dev/packages/sentry_file/score) | [![pub points](https://img.shields.io/pub/points/sentry_file)](https://pub.dev/packages/sentry_file/score)

#### Usage

- Sign up for a Sentry.io account and get a DSN at https://sentry.io.

- Follow the installing instructions on [pub.dev](https://pub.dev/packages/sentry/install).

- Initialize the Sentry SDK using the DSN issued by Sentry.io.

- [Set Up](https://docs.sentry.io/platforms/dart/performance/) Performance.

```dart
import 'package:sentry/sentry.dart';
import 'package:sentry_file/sentry_file.dart';
import 'dart:io';

Future<void> main() async {
  // or SentryFlutter.init
  await Sentry.init(
    (options) {
      options.dsn = 'https://example@sentry.io/example';
      // To set a uniform sample rate
      options.tracesSampleRate = 1.0;
    },
    appRunner: runApp, // Init your App.
  );
}

Future<void> runApp() async {
  final file = File('my_file.txt');
  // Call the Sentry extension method to wrap up the File
  final sentryFile = file.sentryTrace();

  // Start a transaction if there's no active transaction
  final transaction = Sentry.startTransaction(
    'MyFileExample',
    'file',
    bindToScope: true,
  );

  // create the File
  await sentryFile.create();
  // Write some content
  await sentryFile.writeAsString('Hello World');
  // Read the content
  final text = await sentryFile.readAsString();

  print(text);

  // Delete the file
  await sentryFile.delete();

  // Finish the transaction
  await transaction.finish(status: SpanStatus.ok());

  await Sentry.close();
}
```

#### Resources

* [![Documentation](https://img.shields.io/badge/documentation-sentry.io-green.svg)](https://docs.sentry.io/platforms/dart/)
* [![Forum](https://img.shields.io/badge/forum-sentry-green.svg)](https://forum.sentry.io/c/sdks)
* [![Discord](https://img.shields.io/discord/621778831602221064)](https://discord.gg/Ww9hbqr)
* [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](https://stackoverflow.com/questions/tagged/sentry)
* [![Twitter Follow](https://img.shields.io/twitter/follow/getsentry?label=getsentry&style=social)](https://twitter.com/intent/follow?screen_name=getsentry)
