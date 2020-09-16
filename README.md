<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

# Sentry SDK for Dart

[![Build Status](https://travis-ci.org/getsentry/sentry-dart.svg?branch=master)](https://travis-ci.org/getsentry/sentry-dart)
[![pub package](https://img.shields.io/pub/v/sentry.svg)](https://pub.dev/packages/sentry)
[![likes](https://badges.bar/sentry/likes)](https://pub.dev/packages/sentry/score)
[![popularity](https://badges.bar/sentry/popularity)](https://pub.dev/packages/sentry/score)
[![pub points](https://badges.bar/sentry/pub%20points)](https://pub.dev/packages/sentry/score) 

Use this library in your Dart programs (Flutter for mobile, Flutter for web,
command-line, and [AngularDart][angular_sentry]) to report errors thrown by your program to
https://sentry.io error tracking service.

## Versions

Versions `4.0.0` and higher support [Flutter][flutter] (mobile, web, desktop),
command-line/server Dart VM, and [AngularDart][angular_sentry].

Versions below `4.0.0` are deprecated.

## Usage

Sign up for a Sentry.io account and get a DSN at http://sentry.io.

Add `sentry` dependency to your `pubspec.yaml`:

```yaml
dependencies:
  sentry: ">=4.0.0 <5.0.0"
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

## Tips for catching errors

- Use a `try/catch` block, like in the example above.
- Create a `Zone` with an error handler, e.g. using [runZonedGuarded][run_zoned_guarded].

  ```dart
  var sentry = SentryClient(dsn: "https://...");
  // Run the whole app in a zone to capture all uncaught errors.
  runZonedGuarded(
    () => runApp(MyApp()),
    (error, stackTrace) {
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
- For Flutter-specific errors (such as layout failures), use [FlutterError.onError][flutter_error]. For example:

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

## Found a bug?

Please file it at https://github.com/flutter/flutter/issues/new

[flutter]: https://flutter.dev
[run_zoned_guarded]: https://api.dartlang.org/stable/dart-async/runZonedGuarded.html
[flutter_error]: https://docs.flutter.io/flutter/foundation/FlutterError/onError.html
[angular_sentry]: https://pub.dev/packages/angular_sentry
