<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

Sentry SDK for Dart and Flutter
===========

##### Usage

Sign up for a Sentry.io account and get a DSN at http://sentry.io.

In your Dart code, import `package:sentry/sentry.dart` and initialize the Sentry SDK using the DSN issued by Sentry.io:

```dart
import 'package:sentry/sentry.dart';

Sentry.init((options) => options.dsn = 'https://example@sentry.io/add-your-dsn-here');
```

In an exception handler, call `captureException()`:

```dart
import 'dart:async';
import 'package:sentry/sentry.dart';

void main() async {
  try {
    aMethodThatMightFail();
  } catch (exception, stackTrace) {
    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
    );
  }
}
```

##### Tips for catching errors

- Use a `try/catch` block, like in the example above.
- Create a `Zone` with an error handler, e.g. using `runZonedGuarded`.

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:sentry/sentry.dart';

// Wrap your 'runApp(MyApp())' as follows:

Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    runApp(MyApp());
  }, (exception, stackTrace) async {
    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
    );
  });
}
```

- For Flutter-specific errors (such as layout failures), use `FlutterError.onError`. For example:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sentry/sentry.dart';

// Wrap your 'runApp(MyApp())' as follows:

Future<void> main() async {
  FlutterError.onError = (FlutterErrorDetails details) async {
    await Sentry.captureException(
      details.exception,
      stackTrace: details.stack,
    );
  };
}
```
  
- Use `Isolate.current.addErrorListener` to capture uncaught errors
  in the root zone.

#### Resources

* [![Documentation](https://img.shields.io/badge/documentation-sentry.io-green.svg)](https://docs.sentry.io/platforms/flutter/)
* [![Forum](https://img.shields.io/badge/forum-sentry-green.svg)](https://forum.sentry.io/c/sdks)
* [![Discord](https://img.shields.io/discord/621778831602221064)](https://discord.gg/Ww9hbqr)
* [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](https://stackoverflow.com/questions/tagged/sentry)
* [![Twitter Follow](https://img.shields.io/twitter/follow/getsentry?label=getsentry&style=social)](https://twitter.com/intent/follow?screen_name=getsentry)
