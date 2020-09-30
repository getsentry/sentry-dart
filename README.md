<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

Sentry SDK for Dart and Flutter
===========

[![build](https://github.com/getsentry/sentry-dart/workflows/build/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=branch%3Amain)

| package | pub | likes | popularity | pub points |
| ------- | ------- | ------- | ------- | ------- |
| sentry | [![pub package](https://img.shields.io/pub/v/sentry.svg)](https://pub.dev/packages/sentry) | [![likes](https://badges.bar/sentry/likes)](https://pub.dev/packages/sentry/score) | [![popularity](https://badges.bar/sentry/popularity)](https://pub.dev/packages/sentry/score) | [![pub points](https://badges.bar/sentry/pub%20points)](https://pub.dev/packages/sentry/score)  
| sentry-flutter | WIP | | |

## Contributing

### Dart

All you need is the Dart SDK. The `sentry` package doesn't depend on the Flutter SDK.

### Flutter

The SDK currently supports Android, iOS and Web. We build the example app for these targets in 3 platforms: Windows, macOS and Linux.
This is to make sure you'd be able to contribute to this project if you're using any of these operating systems.

We also run CI against the Flutter `stable` and `beta` channels so you should be able to build it if you're in one of those.

### Dependencies

* The Dart SDK (if you want to change `sentry-dart`)
* The Flutter SDK (if you want to change `sentry-dart` or `sentry-flutter`)
* Android: Android SDK with NDK: The example project includes C++.
* iOS: You'll need a Mac with xcode installed.
* Web: No additional dependencies.

#### Sentry Dart


##### Versions

Versions `4.0.0` and higher support [Flutter][flutter] (mobile, web, desktop),
command-line/server Dart VM, and [AngularDart][angular_sentry].

Versions below `4.0.0` are deprecated.

##### Usage

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

##### Tips for catching errors

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

#### Resources

* [![Documentation](https://img.shields.io/badge/documentation-sentry.io-green.svg)](https://docs.sentry.io/platforms/flutter/)
* [![Forum](https://img.shields.io/badge/forum-sentry-green.svg)](https://forum.sentry.io/c/sdks)
* [![Discord](https://img.shields.io/discord/621778831602221064)](https://discord.gg/Ww9hbqr)
* [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](https://stackoverflow.com/questions/tagged/sentry)
* [![Twitter Follow](https://img.shields.io/twitter/follow/getsentry?label=getsentry&style=social)](https://twitter.com/intent/follow?screen_name=getsentry)
