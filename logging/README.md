<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

Sentry integration for `logging` package
===========

| package | build | pub | likes | popularity | pub points |
| ------- | ------- | ------- | ------- | ------- | ------- |
| sentry_logging | [![build](https://github.com/getsentry/sentry-dart/workflows/sentry-logging/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Alogging) | [![pub package](https://img.shields.io/pub/v/sentry_logging.svg)](https://pub.dev/packages/sentry_logging) | [![likes](https://img.shields.io/pub/likes/sentry_logging)](https://pub.dev/packages/sentry_logging/score) | [![popularity](https://img.shields.io/pub/popularity/sentry_logging)](https://pub.dev/packages/sentry_logging/score) | [![pub points](https://img.shields.io/pub/points/sentry_logging)](https://pub.dev/packages/sentry_logging/score)

Integration for the [`logging`](https://pub.dev/packages/logging) package.

#### Usage

- Sign up for a Sentry.io account and get a DSN at https://sentry.io.

- Follow the installing instructions on [pub.dev](https://pub.dev/packages/sentry/install).

- Initialize the Sentry SDK using the DSN issued by Sentry.io and add the `LoggingIntegration`

```dart
import 'package:sentry/sentry.dart';
import 'package:sentry_logging/sentry_logging.dart';

Future<void> main() async {
  await Sentry.init(
    (options) {
      options.dsn = 'https://example@sentry.io/example';
      options.addIntegration(LoggingIntegration());
    },
    appRunner: initApp, // Init your App.
  );
}

void initApp() {
  // your app code
}
```

#### Resources

* [![Flutter docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=flutter%20docs)](https://docs.sentry.io/platforms/flutter/)
* [![Dart docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=dart%20docs)](https://docs.sentry.io/platforms/dart/)
* [![Discussions](https://img.shields.io/github/discussions/getsentry/sentry-dart.svg)](https://github.com/getsentry/sentry-dart/discussions)
* [![Discord Chat](https://img.shields.io/discord/621778831602221064?logo=discord&logoColor=ffffff&color=7389D8)](https://discord.gg/PXa5Apfe7K)
* [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](https://stackoverflow.com/questions/tagged/sentry)
* [![Twitter Follow](https://img.shields.io/twitter/follow/getsentry?label=getsentry&style=social)](https://twitter.com/intent/follow?screen_name=getsentry)