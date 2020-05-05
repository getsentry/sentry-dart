# Sentry.io client for Dart

[![Build Status](https://travis-ci.org/flutter/sentry.svg?branch=master)](https://travis-ci.org/flutter/sentry)
[![pub package](https://img.shields.io/pub/v/sentry.svg)](https://pub.dev/packages/sentry) 

Use this library in your Dart programs (Flutter for mobile, Flutter for web,
command-line, and AngularDart) to report errors thrown by your program to
https://sentry.io error tracking service.

## Versions

Versions `3.0.0` and higher support Flutter for mobile, Flutter for web,
command-line, desktop, and AngularDart.

`>=2.0.0 <3.0.0` is the range of versions that support Flutter for mobile and
Dart VM only.

Versions `<2.0.0` are deprecated.

## Usage

Sign up for a Sentry.io account and get a DSN at http://sentry.io.

Add `sentry` dependency to your `pubspec.yaml`:

```yaml
dependencies:
  sentry: ">=3.0.0 <4.0.0"
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
- Create a `Zone` with an error handler, e.g. using [runZoned][run_zoned].

  ```dart
  var sentry = SentryClient(dsn: "https://...");
  // Run the whole app in a zone to capture all uncaught errors.
  runZoned(
    () => runApp(MyApp()),
    onError: (Object error, StackTrace stackTrace) {
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

[run_zoned]: https://api.dartlang.org/stable/dart-async/runZoned.html
[flutter_error]: https://docs.flutter.io/flutter/foundation/FlutterError/onError.html

## Found a bug?

Please file it at https://github.com/flutter/flutter/issues/new
