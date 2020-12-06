<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

Sentry SDK for Dart
===========

| package | build | pub | likes | popularity | pub points |
| ------- | ------- | ------- | ------- | ------- | ------- |
| sentry | [![build](https://github.com/getsentry/sentry-dart/workflows/sentry-dart/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-dart) | [![pub package](https://img.shields.io/pub/v/sentry.svg)](https://pub.dev/packages/sentry) | [![likes](https://badges.bar/sentry/likes)](https://pub.dev/packages/sentry/score) | [![popularity](https://badges.bar/sentry/popularity)](https://pub.dev/packages/sentry/score) | [![pub points](https://badges.bar/sentry/pub%20points)](https://pub.dev/packages/sentry/score)

Pure Dart SDK used by any Dart application like AngularDart, CLI and server. 

#### Flutter

For Flutter applications there's [`sentry_flutter`](https://pub.dev/packages/sentry_flutter) which builds on top of this package.
That will give you native crash support (for Android and iOS), [release health](https://docs.sentry.io/product/releases/health/), offline caching and more.

#### Versions

Versions `^4.0.0-alpha.1` are `Prereleases` and are under improvements/testing.

The current stable version is the Dart SDK, [3.0.1](https://pub.dev/packages/sentry).

#### Usage

- Sign up for a Sentry.io account and get a DSN at http://sentry.io.

- Follow the installing instructions on [pub.dev](https://pub.dev/packages/sentry/install).

- The code snippet below reflects the latest `Prerelease` version.

- Initialize the Sentry SDK using the DSN issued by Sentry.io:

```dart
import 'dart:async';
import 'package:sentry/sentry.dart';

Future<void> main() async {
  await Sentry.init(
    (options) {
      options.dsn = 'https://example@sentry.io/add-your-dsn-here';
    },
    appRunner: initApp, // Init your App.
  );
}

void initApp() {
  // your app code
}
```

Or, if you want to run your app in your own error zone [runZonedGuarded]:  

```dart
import 'dart:async';
import 'package:sentry/sentry.dart';

Future<void> main() async {
  await Sentry.init(
    (options) {
      options.dsn = 'https://example@sentry.io/add-your-dsn-here';
    },
  );

  // Init your App.
  initApp();
}

void initApp() {
  // your app code
}
```

##### Breadcrumbs for HTTP Requests

The `SentryHttpClient` can be used as a standalone client like this:
```dart
import 'package:sentry/sentry.dart';

var client = SentryHttpClient();
try {
 var uriResponse = await client.post('https://example.com/whatsit/create',
     body: {'name': 'doodle', 'color': 'blue'});
 print(await client.get(uriResponse.bodyFields['uri']));
} finally {
 client.close();
}
```

The `SentryHttpClient` can also be used as a wrapper for your own
HTTP [Client](https://pub.dev/documentation/http/latest/http/Client-class.html):
```dart
import 'package:sentry/sentry.dart';
import 'package:http/http.dart' as http;

final myClient = http.Client();

var client = SentryHttpClient(client: myClient);
try {
var uriResponse = await client.post('https://example.com/whatsit/create',
     body: {'name': 'doodle', 'color': 'blue'});
 print(await client.get(uriResponse.bodyFields['uri']));
} finally {
 client.close();
}
```

##### Tips for catching errors

- Use a `try/catch` block.
- Use a `catchError` block for `Futures`, examples on [dart.dev](https://dart.dev/guides/libraries/futures-error-handling).
- The SDK already runs your `callback` on an error handler, e.g. using [runZonedGuarded](https://api.flutter.dev/flutter/dart-async/runZonedGuarded.html), events caught by the `runZonedGuarded` are captured automatically.
- [Current Isolate errors](https://api.flutter.dev/flutter/dart-isolate/Isolate/addErrorListener.html) which is the equivalent of a main or UI thread, are captured automatically (Only for non-Web Apps).
- For your own `Isolates`, add an [Error Listener](https://api.flutter.dev/flutter/dart-isolate/Isolate/addErrorListener.html) and call `Sentry.captureException`.

#### Resources

* [![Documentation](https://img.shields.io/badge/documentation-sentry.io-green.svg)](https://docs.sentry.io/platforms/dart/)
* [![Forum](https://img.shields.io/badge/forum-sentry-green.svg)](https://forum.sentry.io/c/sdks)
* [![Discord](https://img.shields.io/discord/621778831602221064)](https://discord.gg/Ww9hbqr)
* [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](https://stackoverflow.com/questions/tagged/sentry)
* [![Twitter Follow](https://img.shields.io/twitter/follow/getsentry?label=getsentry&style=social)](https://twitter.com/intent/follow?screen_name=getsentry)
