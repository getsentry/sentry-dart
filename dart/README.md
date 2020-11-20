<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

Sentry SDK for Dart and Flutter
===========

##### Usage

- Sign up for a Sentry.io account and get a DSN at http://sentry.io.

- Follow the installing instructions on [pub.dev](https://pub.dev/packages/sentry/install).

- The code snippet below reflects the latest `Prerelease` version.

- Initialize the Sentry SDK using the DSN issued by Sentry.io:

```dart
import 'package:sentry/sentry.dart';

Sentry.init((options) => options.dsn = 'https://example@sentry.io/add-your-dsn-here');
```

In an exception handler, call `captureException()`:

```dart
import 'dart:async';
import 'package:sentry/sentry.dart';

Future<void> main() async {
  await Sentry.init(
    (options) => options.dsn = 'https://example@sentry.io/add-your-dsn-here',
  );

  try {
    aMethodThatMightFail();
  } catch (exception, stackTrace) {
    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
    );
  }
}

void aMethodThatMightFail() {
  throw null;
}
```

##### Flutter SDK Integration

- Check out the [Flutter SDK Integration](https://github.com/getsentry/sentry-dart/tree/main/flutter)

#### Resources

* [![Documentation](https://img.shields.io/badge/documentation-sentry.io-green.svg)](https://docs.sentry.io/platforms/flutter/)
* [![Forum](https://img.shields.io/badge/forum-sentry-green.svg)](https://forum.sentry.io/c/sdks)
* [![Discord](https://img.shields.io/discord/621778831602221064)](https://discord.gg/Ww9hbqr)
* [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](https://stackoverflow.com/questions/tagged/sentry)
* [![Twitter Follow](https://img.shields.io/twitter/follow/getsentry?label=getsentry&style=social)](https://twitter.com/intent/follow?screen_name=getsentry)
