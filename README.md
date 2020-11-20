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
| sentry-flutter | [![build](https://github.com/getsentry/sentry-dart/workflows/sentry-flutter/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-flutter) | | | |

## Contributing

### Dart

All you need is the [sentry-dart](https://github.com/getsentry/sentry-dart/tree/main/dart). The `sentry` package doesn't depend on the Flutter SDK.

### Flutter

The SDK currently supports Android, iOS and Web. We build the example app for these targets in 3 platforms: Windows, macOS and Linux.
This is to make sure you'd be able to contribute to this project if you're using any of these operating systems.

We also run CI against the Flutter `stable` and `beta` channels so you should be able to build it if you're in one of those.

### Dependencies

* The Dart SDK (if you want to change `sentry-dart`)
* The Flutter SDK (if you want to change `sentry-dart`) or `sentry-flutter`)
* Android: Android SDK with NDK: The example project includes C++.
* iOS: You'll need a Mac with xcode installed.
* Web: No additional dependencies.

#### Sentry Dart


##### Versions

Versions `^4.0.0` are `Prereleases` and are under improvements/testing.
Versions `^4.0.0` integrate our Native SDKs ([Android](https://github.com/getsentry/sentry-java) and [Apple](https://github.com/getsentry/sentry-cocoa)), so you are able to capture errors on Native code as well (Java/Kotlin/C/C++ for Android and Objective-C/Swift for Apple).

The current stable version is `3.0.1`.
Versions `3.0.1` and higher support `Flutter` (mobile, web, desktop) but they don't integrate the Native SDKs (Apple/Android),
command-line/server Dart VM, and `AngularDart`.

Versions below `3.0.1` are deprecated.

##### Usage

- Sign up for a Sentry.io account and get a DSN at http://sentry.io.

- Follow the installing instructions on [pub.dev](https://pub.dev/packages/sentry_flutter/install).

- The code snippet below reflects the latest `Prerelease` version.

- Initialize the Sentry SDK using the DSN issued by Sentry.io:

```dart
import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://example@sentry.io/add-your-dsn-here';
      // Change the 'sentry_flutter_example' below with your own App's package.
      options.addInAppInclude('sentry_flutter_example');
    },
    (Function callback) => {
      // Init your App.
      runApp(MyApp()),
    },
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

##### Tips for catching errors

- Use a `try/catch` block, like in the example above.
- Use a `catchError` block for `Futures`, examples on [dart.dev](https://dart.dev/guides/libraries/futures-error-handling).
- The SDK already runs your App. on an error handler, e.g. using [runZonedGuarded](https://api.flutter.dev/flutter/dart-async/runZonedGuarded.html), events caught by the `runZonedGuarded` are captured automatically.
- [Flutter-specific errors](https://api.flutter.dev/flutter/foundation/FlutterError/onError.html) (such as layout failures) are captured automatically.
- [Current Isolate errors](https://api.flutter.dev/flutter/dart-isolate/Isolate/addErrorListener.html) are captured automatically.
- For your own `Isolates`, add an [Error Listener]((https://api.flutter.dev/flutter/dart-isolate/Isolate/addErrorListener.html)) and call `Sentry.captureException`.

#### Resources

* [![Documentation](https://img.shields.io/badge/documentation-sentry.io-green.svg)](https://docs.sentry.io/platforms/flutter/)
* [![Forum](https://img.shields.io/badge/forum-sentry-green.svg)](https://forum.sentry.io/c/sdks)
* [![Discord](https://img.shields.io/discord/621778831602221064)](https://discord.gg/Ww9hbqr)
* [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](https://stackoverflow.com/questions/tagged/sentry)
* [![Twitter Follow](https://img.shields.io/twitter/follow/getsentry?label=getsentry&style=social)](https://twitter.com/intent/follow?screen_name=getsentry)
