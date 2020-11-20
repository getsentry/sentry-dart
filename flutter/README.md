<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

Sentry SDK for Flutter and its Native integrations (Android/Apple)
===========

| package | build |
| ------- | ------- |
| sentry_flutter | [![build](https://github.com/getsentry/sentry-dart/workflows/sentry-flutter/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-flutter) |

#### Versions

Versions `^4.0.0` are `Prereleases` and are under improvements/testing.

Versions `^4.0.0` integrate our Native SDKs ([Android](https://github.com/getsentry/sentry-java) and [Apple](https://github.com/getsentry/sentry-cocoa)), so you are able to capture errors on Native code as well (Java/Kotlin/C/C++ for Android and Objective-C/Swift for Apple).

The current stable version is the Dart SDK, [3.0.1](https://pub.dev/packages/sentry).

#### Usage

- Sign up for a Sentry.io account and get a DSN at http://sentry.io.

- Follow the installing instructions on [pub.dev](https://pub.dev/packages/sentry_flutter/install).

- The code snippet below reflects the latest `Prerelease` version.

- Initialize the Sentry SDK using the DSN issued by Sentry.io:

```dart
import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://example@sentry.io/add-your-dsn-here';
      // For better groupping, change the 'example' below with your own App's package.
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

##### Known limitations

- We don't support the Flutter `split-debug-info` yet, if this feature is enabled, it'll give useless stack traces.
- For the Flutter [obfuscate](https://flutter.dev/docs/deployment/obfuscate) feature, you'll need to upload the Debug symbols manually yet, See the section below.

##### Debug Symbols for the Native integrations (Android and Apple)

[Uploading Debug Symbols](https://docs.sentry.io/platforms/apple/dsym/) for Apple.

[Uploading Proguard Mappings and Debug Symbols](https://docs.sentry.io/platforms/android/proguard/) for Android.

##### Tips for catching errors

- Use a `try/catch` block, like in the example above.
- Use a `catchError` block for `Futures`, examples on [dart.dev](https://dart.dev/guides/libraries/futures-error-handling).
- The SDK already runs your `callback` on an error handler, e.g. using [runZonedGuarded](https://api.flutter.dev/flutter/dart-async/runZonedGuarded.html), events caught by the `runZonedGuarded` are captured automatically.
- [Flutter-specific errors](https://api.flutter.dev/flutter/foundation/FlutterError/onError.html) (such as layout failures) are captured automatically.
- [Current Isolate errors](https://api.flutter.dev/flutter/dart-isolate/Isolate/addErrorListener.html) which is the equivalent of a main or UI thread, are captured automatically.
- For your own `Isolates`, add an [Error Listener](https://api.flutter.dev/flutter/dart-isolate/Isolate/addErrorListener.html) and call `Sentry.captureException`.

#### Resources

* [![Documentation](https://img.shields.io/badge/documentation-sentry.io-green.svg)](https://docs.sentry.io/platforms/flutter/)
* [![Forum](https://img.shields.io/badge/forum-sentry-green.svg)](https://forum.sentry.io/c/sdks)
* [![Discord](https://img.shields.io/discord/621778831602221064)](https://discord.gg/Ww9hbqr)
* [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](https://stackoverflow.com/questions/tagged/sentry)
* [![Twitter Follow](https://img.shields.io/twitter/follow/getsentry?label=getsentry&style=social)](https://twitter.com/intent/follow?screen_name=getsentry)
