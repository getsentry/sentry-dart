# Sentry.io client for Dart

[![Build Status](https://travis-ci.org/flutter/sentry.svg?branch=master)](https://travis-ci.org/flutter/sentry)

Use this library in your Dart programs (Flutter, command-line and (TBD) AngularDart) to report errors thrown by your
program to https://sentry.io error tracking service.

## Versions

`>=0.0.0 <2.0.0` is the range of versions compatible with Dart 1.

`>=2.0.0 <3.0.0` is the range of versions compatible with Dart 2.

## Usage

Sign up for a Sentry.io account and get a DSN at http://sentry.io.

Add `sentry` dependency to your `pubspec.yaml`:

```yaml
dependencies:
  sentry: any
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
      sentry.captureException(
        exception: error,
        stackTrace: stackTrace,
      );
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
    } finally {
      // Also use Flutter's default error logging to the device's console.
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
