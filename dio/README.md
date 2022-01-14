<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

Sentry integration for `dio` package
===========

| package | build | pub | likes | popularity | pub points |
| ------- | ------- | ------- | ------- | ------- | ------- |
| sentry | [![build](https://github.com/getsentry/sentry-dart/workflows/sentry-dio/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-dio) | [![pub package](https://img.shields.io/pub/v/sentry_dio.svg)](https://pub.dev/packages/sentry_dio) | [![likes](https://badges.bar/sentry_dio/likes)](https://pub.dev/packages/sentry_dio/score) | [![popularity](https://badges.bar/sentry_dio/popularity)](https://pub.dev/packages/sentry_dio/score) | [![pub points](https://badges.bar/sentry_dio/pub%20points)](https://pub.dev/packages/sentry_dio/score)

Integration for the [`dio`](https://pub.dev/packages/dio) package.

#### Flutter

For Flutter applications there's [`sentry_flutter`](https://pub.dev/packages/sentry_flutter) which builds on top of this package.
That will give you native crash support (for Android and iOS), [release health](https://docs.sentry.io/product/releases/health/), offline caching and more.

#### Usage

- Sign up for a Sentry.io account and get a DSN at http://sentry.io.

- Follow the installing instructions on [pub.dev](https://pub.dev/packages/sentry/install).

- Initialize the Sentry SDK using the DSN issued by Sentry.io:

```dart
import 'package:sentry/sentry.dart';
import 'package:sentry_dio/sentry_dio.dart';

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
  // Make sure this is the last initialization method, 
  // otherwise you might override Sentrys configuration.
  dio.addSentry(...);
}
```

Dependending on you configuration, this can add performance tracing, 
http breadcrumbs and automatic recording of bad http requests.

#### Resources

* [![Documentation](https://img.shields.io/badge/documentation-sentry.io-green.svg)](https://docs.sentry.io/platforms/dart/)
* [![Forum](https://img.shields.io/badge/forum-sentry-green.svg)](https://forum.sentry.io/c/sdks)
* [![Discord](https://img.shields.io/discord/621778831602221064)](https://discord.gg/Ww9hbqr)
* [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](https://stackoverflow.com/questions/tagged/sentry)
* [![Twitter Follow](https://img.shields.io/twitter/follow/getsentry?label=getsentry&style=social)](https://twitter.com/intent/follow?screen_name=getsentry)