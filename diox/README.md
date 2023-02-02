<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

Sentry integration for `diox` package
===========

| package | build | pub | likes | popularity | pub points |
| ------- | ------- | ------- | ------- | ------- | ------- |
| sentry_diox | [![build](https://github.com/getsentry/sentry-dart/workflows/sentry-diox/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-diox) | [![pub package](https://img.shields.io/pub/v/sentry_diox.svg)](https://pub.dev/packages/sentry_diox) | [![likes](https://img.shields.io/pub/likes/sentry_diox)](https://pub.dev/packages/sentry_diox/score) | [![popularity](https://img.shields.io/pub/popularity/sentry_diox)](https://pub.dev/packages/sentry_diox/score) | [![pub points](https://img.shields.io/pub/points/sentry_diox)](https://pub.dev/packages/sentry_diox/score)

Integration for the [`diox`](https://pub.dev/packages/diox) package.

#### Usage

- Sign up for a Sentry.io account and get a DSN at https://sentry.io.

- Follow the installing instructions on [pub.dev](https://pub.dev/packages/sentry/install).

- Initialize the Sentry SDK using the DSN issued by Sentry.io.

- Call `dio.addSentry()`. This *must* be the last initialization step of the Dio setup, otherwise your configuration of Dio might overwrite the Sentry configuration.

```dart
import 'package:sentry/sentry.dart';
import 'package:sentry_diox/sentry_diox.dart';

Future<void> main() async {
  await Sentry.init(
    (options) {
      options.dsn = 'https://example@sentry.io/example';
    },
    appRunner: initDio, // Init your App.
  );
}

void initDio() {
  final dio = Dio();
  /// This *must* be the last initialization step of the Dio setup, otherwise
  /// your configuration of Dio might overwrite the Sentry configuration.
  dio.addSentry(...);
}
```

Depending on your configuration, this adds performance tracing and http breadcrumbs. Also, exceptions from invalid http status codes or parsing exceptions are automatically captured.

#### Resources

* [![Documentation](https://img.shields.io/badge/documentation-sentry.io-green.svg)](https://docs.sentry.io/platforms/dart/)
* [![Forum](https://img.shields.io/badge/forum-sentry-green.svg)](https://forum.sentry.io/c/sdks)
* [![Discord](https://img.shields.io/discord/621778831602221064)](https://discord.gg/Ww9hbqr)
* [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](https://stackoverflow.com/questions/tagged/sentry)
* [![Twitter Follow](https://img.shields.io/twitter/follow/getsentry?label=getsentry&style=social)](https://twitter.com/intent/follow?screen_name=getsentry)
