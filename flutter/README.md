<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

Sentry SDK for Flutter
===========

| package | build | pub | likes | popularity | pub points |
| ------- | ------- | ------- | ------- | ------- | ------- |
| sentry_flutter | [![build](https://github.com/getsentry/sentry-dart/workflows/sentry-flutter/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-flutter) | [![pub package](https://img.shields.io/pub/v/sentry_flutter.svg)](https://pub.dev/packages/sentry_flutter) | [![likes](https://badges.bar/sentry_flutter/likes)](https://pub.dev/packages/sentry_flutter/score) | [![popularity](https://badges.bar/sentry_flutter/popularity)](https://pub.dev/packages/sentry_flutter/score) | [![pub points](https://badges.bar/sentry_flutter/pub%20points)](https://pub.dev/packages/sentry_flutter/score)

This package includes support to native crashes through Sentry's native SDKs: ([Android](https://github.com/getsentry/sentry-java) and [iOS](https://github.com/getsentry/sentry-cocoa)).
It will capture errors in the native layer, including (Java/Kotlin/C/C++ for Android and Objective-C/Swift for iOS).

#### Usage

- Sign up for a Sentry.io account and get a DSN at http://sentry.io.

- Follow the installing instructions on [pub.dev](https://pub.dev/packages/sentry_flutter/install).

- Initialize the Sentry SDK using the DSN issued by Sentry.io:

```dart
import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://example@sentry.io/add-your-dsn-here';
    },
    // Init your App.
    appRunner: () => runApp(MyApp()),
  );
}
```

Or, if you want to run your app in your own error zone [runZonedGuarded](https://api.flutter.dev/flutter/dart-async/runZonedGuarded.html):

```dart
import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://example@sentry.io/add-your-dsn-here';
    },
  );

  runApp(MyApp());
}
```

##### Tracking navigation events

In order to track navigation events you have to add the 
`SentryNavigationObserver` to your `MaterialApp`, `WidgetsApp` or `CupertinoApp`.

```dart
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

// ...
MaterialApp(
  navigatorObservers: [
    SentryNavigatorObserver(),
  ],
  // other parameters
)
// ...
```
For a more throughout example see the [example](example/lib/main.dart).

##### Known limitations

- Flutter `split-debug-info` and `obfuscate` flag aren't supported on iOS yet, but only on Android, if this feature is enabled, Dart stack traces are not human readable
- If you enable the `split-debug-info` feature, you must upload the Debug Symbols manually.
- Layout related errors are only caught by [FlutterError.onError](https://api.flutter.dev/flutter/foundation/FlutterError/onError.html) in debug mode. In release mode, they are removed by the Flutter framework. See [Flutter build modes](https://flutter.dev/docs/testing/build-modes). 

##### Uploading Debug Symbols (Android and iOS)

- [iOS dSYM files](https://docs.sentry.io/platforms/apple/dsym/)
- [Android NDK](https://docs.sentry.io/product/cli/dif/#uploading-files), You must to do it manually. Do not use the `uploadNativeSymbols` flag from the [Sentry Gradle Plugin](https://docs.sentry.io/platforms/android/proguard/), because it's not yet supported.
- [Android Proguard/R8 mapping file](https://docs.sentry.io/platforms/android/proguard/)
- [Source maps for Flutter Web](https://docs.sentry.io/product/cli/releases/#managing-release-artifacts)

##### Tips for catching errors

- Use a `try/catch` block.
- Use a `catchError` block for `Futures`, examples on [dart.dev](https://dart.dev/guides/libraries/futures-error-handling).
- The SDK already runs your `callback` on an error handler, e.g. using [runZonedGuarded](https://api.flutter.dev/flutter/dart-async/runZonedGuarded.html), events caught by the `runZonedGuarded` are captured automatically.
- [Flutter-specific errors](https://api.flutter.dev/flutter/foundation/FlutterError/onError.html) are captured automatically.
- [Current Isolate errors](https://api.flutter.dev/flutter/dart-isolate/Isolate/addErrorListener.html) which is the equivalent of a main or UI thread, are captured automatically (Only for non-Web Apps).
- For your own `Isolates`, add an [Error Listener](https://api.flutter.dev/flutter/dart-isolate/Isolate/addErrorListener.html) and call `Sentry.captureException`.

#### Resources

* [![Documentation](https://img.shields.io/badge/documentation-sentry.io-green.svg)](https://docs.sentry.io/platforms/flutter/)
* [![Forum](https://img.shields.io/badge/forum-sentry-green.svg)](https://forum.sentry.io/c/sdks)
* [![Discord](https://img.shields.io/discord/621778831602221064)](https://discord.gg/Ww9hbqr)
* [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](https://stackoverflow.com/questions/tagged/sentry)
* [![Twitter Follow](https://img.shields.io/twitter/follow/getsentry?label=getsentry&style=social)](https://twitter.com/intent/follow?screen_name=getsentry)
