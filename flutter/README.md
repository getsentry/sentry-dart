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
| sentry_flutter | [![build](https://github.com/getsentry/sentry-dart/workflows/sentry-flutter/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-flutter) | [![pub package](https://img.shields.io/pub/v/sentry_flutter.svg)](https://pub.dev/packages/sentry_flutter) | [![likes](https://img.shields.io/pub/likes/sentry_flutter)](https://pub.dev/packages/sentry_flutter/score) | [![popularity](https://img.shields.io/pub/popularity/sentry_flutter)](https://pub.dev/packages/sentry_flutter/score) | [![pub points](https://img.shields.io/pub/points/sentry_flutter)](https://pub.dev/packages/sentry_flutter/score)

This package includes support to native crashes through Sentry's native SDKs: ([Android](https://github.com/getsentry/sentry-java) and [iOS](https://github.com/getsentry/sentry-cocoa)).
It will capture errors in the native layer, including (Java/Kotlin/C/C++ for Android and Objective-C/Swift for iOS).

#### Usage

- Sign up for a Sentry.io account and get a DSN at https://sentry.io.

- Follow the installing instructions on [pub.dev](https://pub.dev/packages/sentry_flutter/install).

- Initialize the Sentry SDK using the DSN issued by Sentry.io:

- The SDK already runs your init `callback` on an error handler, such as [`runZonedGuarded`](https://api.flutter.dev/flutter/dart-async/runZonedGuarded.html) on Flutter versions prior to `3.3`, or [`PlatformDispatcher.onError`](https://api.flutter.dev/flutter/dart-ui/PlatformDispatcher/onError.html) on Flutter versions 3.3 and higher, so that errors are automatically captured.

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

Prior to Flutter 3.3, if you want to run your app in your own error zone [runZonedGuarded](https://api.flutter.dev/flutter/dart-async/runZonedGuarded.html):

```dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    await SentryFlutter.init(
      (options) {
        options.dsn = 'https://example@sentry.io/add-your-dsn-here';
      },
    );

    runApp(MyApp());
  }, (exception, stackTrace) async {
    await Sentry.captureException(exception, stackTrace: stackTrace);
  });
}
```

##### Tracking navigation events

In order to track navigation events you have to add the 
`SentryNavigatorObserver` to your `MaterialApp`, `WidgetsApp` or `CupertinoApp`.

You should provide a name to route settings: `RouteSettings(name: 'Your Route Name')`. The root 
route name `/` will be replaced by `root "/"` for clarity's sake.

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
For a more throughout example see the [example](https://github.com/getsentry/sentry-dart/blob/main/flutter/example/lib/main.dart).

##### Performance tracing for `AssetBundle`s

Sentry has support for tracing [`AssetBundle`](https://api.flutter.dev/flutter/services/AssetBundle-class.html)s. It can be added with the following code:

```dart
runApp(
  DefaultAssetBundle(
    bundle: SentryAssetBundle(),
    child: MyApp(),
  ),
);
```

This adds performance tracing for all `AssetBundle` usages, where the `AssetBundle` is accessed with `DefaultAssetBundle.of(context)`.
This includes all of Flutters internal access of `AssetBundle`s, like `Image.asset` for example.

##### Tracking HTTP events

Please see the instructions [here](https://pub.dev/packages/sentry).

##### Known limitations

- If you enable the `split-debug-info` feature, you must upload the Debug Symbols manually.
- Layout related errors are only caught by [FlutterError.onError](https://api.flutter.dev/flutter/foundation/FlutterError/onError.html) in debug mode. In release mode, they are removed by the Flutter framework. See [Flutter build modes](https://flutter.dev/docs/testing/build-modes).

##### Uploading Debug Symbols and Source maps (Android, iOS/macOS and Web)

Debug symbols and Source maps provide information that Sentry displays on the Issue Details page to help you triage an issue. We offer a range of methods to provide Sentry with debug symbols, [follow the docs](https://docs.sentry.io/platforms/flutter/upload-debug/) to learn more about it.

Or [try out the Alpha version of the Sentry Dart Plugin](https://github.com/getsentry/sentry-dart-plugin) that does it automatically for you, feedback is welcomed.

##### Tips for catching errors

- Use a `try/catch` block.
- Use a `catchError` block for `Futures`, examples on [dart.dev](https://dart.dev/guides/libraries/futures-error-handling).
- [Flutter-specific errors](https://api.flutter.dev/flutter/foundation/FlutterError/onError.html) are captured automatically.
- [Current Isolate errors](https://api.flutter.dev/flutter/dart-isolate/Isolate/addErrorListener.html) which is the equivalent of a main or UI thread, are captured automatically (Only for non-Web Apps).
- For your own `Isolates`, add an [Error Listener](https://api.flutter.dev/flutter/dart-isolate/Isolate/addErrorListener.html) by calling `isolate.addSentryErrorListener()`.

#### Resources

* [![Flutter docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=flutter%20docs)](https://docs.sentry.io/platforms/flutter/)
* [![Dart docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=dart%20docs)](https://docs.sentry.io/platforms/dart/)
* [![Discussions](https://img.shields.io/github/discussions/getsentry/sentry-dart.svg)](https://github.com/getsentry/sentry-dart/discussions)
* [![Discord Chat](https://img.shields.io/discord/621778831602221064?logo=discord&logoColor=ffffff&color=7389D8)](https://discord.gg/PXa5Apfe7K)
* [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](https://stackoverflow.com/questions/tagged/sentry)
* [![Twitter Follow](https://img.shields.io/twitter/follow/getsentry?label=getsentry&style=social)](https://twitter.com/intent/follow?screen_name=getsentry)
