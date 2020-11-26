<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

Sentry SDK for Dart and Flutter
===========

| package | build | pub | likes | popularity | pub points |
| ------- | ------- | ------- | ------- | ------- | ------- |
| sentry | [![build](https://github.com/getsentry/sentry-dart/workflows/sentry-dart/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-dart) | [![pub package](https://img.shields.io/pub/v/sentry.svg)](https://pub.dev/packages/sentry) | [![likes](https://badges.bar/sentry/likes)](https://pub.dev/packages/sentry/score) | [![popularity](https://badges.bar/sentry/popularity)](https://pub.dev/packages/sentry/score) | [![pub points](https://badges.bar/sentry/pub%20points)](https://pub.dev/packages/sentry/score)
| sentry_flutter | [![build](https://github.com/getsentry/sentry-dart/workflows/sentry-flutter/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-flutter) | [![pub package](https://img.shields.io/pub/v/sentry_flutter.svg)](https://pub.dev/packages/sentry_flutter) | [![likes](https://badges.bar/sentry_flutter/likes)](https://pub.dev/packages/sentry_flutter/score) | [![popularity](https://badges.bar/sentry_flutter/popularity)](https://pub.dev/packages/sentry_flutter/score) | [![pub points](https://badges.bar/sentry_flutter/pub%20points)](https://pub.dev/packages/sentry_flutter/score)

##### Versions

Versions `3.0.1` and higher support `Flutter` (mobile, web, desktop),
command-line/server Dart VM, and `AngularDart`.

Versions below `3.0.1` are deprecated.

###### Preleases (v4.0.0)

- If you wish to try out our Prelease versions, check out the inner [dart](https://github.com/getsentry/sentry-dart/tree/main/dart) and [flutter](https://github.com/getsentry/sentry-dart/tree/main/flutter) folders. 

##### Usage

Sign up for a Sentry.io account and get a DSN at http://sentry.io.

Add `sentry` dependency to your `pubspec.yaml`:

```yaml
dependencies:
  sentry: ">=3.0.1 <4.0.0"
```

In your Dart code, import `package:sentry/sentry.dart` and create a `SentryClient` using the DSN issued by Sentry.io:

```dart
import 'package:sentry/sentry.dart';

final SentryClient sentry = new SentryClient(dsn: YOUR_DSN);
```

In an exception handler, call `captureException()`:

```dart
main() async {
  try {
    doSomethingThatMightThrowAnError();
  } catch(error, stackTrace) {
    await sentry.captureException(
      exception: error,
      stackTrace: stackTrace,
    );
  }
}
```

##### Tips for catching errors

- Use a `try/catch` block, like in the example above.
- Create a `Zone` with an error handler, e.g. using `runZonedGuarded`.

  ```dart
  var sentry = SentryClient(dsn: "https://...");
  // Run the whole app in a zone to capture all uncaught errors.
  runZonedGuarded(
    () => runApp(MyApp()),
    (error, stackTrace) async {
      try {
        sentry.captureException(
          exception: error,
          stackTrace: stackTrace,
        );
        print('Error sent to sentry.io: $error');
      } catch (e) {
        print('Sending report to sentry.io failed: $e');
        print('Original error: $error');
      }
    },
  );
  ```
- For Flutter-specific errors (such as layout failures), use `FlutterError.onError`. For example:

  ```dart
  var sentry = SentryClient(dsn: "https://...");
  FlutterError.onError = (details, {bool forceReport = false}) {
    try {
      sentry.captureException(
        exception: details.exception,
        stackTrace: details.stack,
      );
    } catch (e) {
      print('Sending report to sentry.io failed: $e');
    } finally {
      // Also use Flutter's pretty error logging to the device's console.
      FlutterError.dumpErrorToConsole(details, forceReport: forceReport);
    }
  };
  ```
- Use `Isolate.current.addErrorListener` to capture uncaught errors
  in the root zone.

#### Resources

* [![Flutter docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=flutter%20docs)](https://docs.sentry.io/platforms/flutter/)
* [![Dart docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=dart%20docs)](https://docs.sentry.io/platforms/dart/)
* [![Forum](https://img.shields.io/badge/forum-sentry-green.svg)](https://forum.sentry.io/c/sdks)
* [![Discord](https://img.shields.io/discord/621778831602221064)](https://discord.gg/Ww9hbqr)
* [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](https://stackoverflow.com/questions/tagged/sentry)
* [![Twitter Follow](https://img.shields.io/twitter/follow/getsentry?label=getsentry&style=social)](https://twitter.com/intent/follow?screen_name=getsentry)
