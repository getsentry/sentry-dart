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
| sentry | [![build](https://github.com/getsentry/sentry-dart/workflows/sentry-dart/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-dart) | [![pub package](https://img.shields.io/pub/v/sentry.svg)](https://pub.dev/packages/sentry) | [![likes](https://img.shields.io/pub/likes/sentry)](https://pub.dev/packages/sentry/score) | [![popularity](https://img.shields.io/pub/popularity/sentry)](https://img.shields.io/pub/sentry) | [![pub points](https://img.shields.io/pub/points/sentry)](https://pub.dev/packages/sentry/score)

Pure Dart SDK used by any Dart application like AngularDart, CLI and Server.

#### Flutter

For Flutter applications there's [`sentry_flutter`](https://pub.dev/packages/sentry_flutter) which builds on top of this package.
That will give you native crash support (for Android and iOS), [release health](https://docs.sentry.io/product/releases/health/), offline caching and more.

#### Usage

- Sign up for a Sentry.io account and get a DSN at https://sentry.io.

- Follow the installing instructions on [pub.dev](https://pub.dev/packages/sentry/install).

- Initialize the Sentry SDK using the DSN issued by Sentry.io:

```dart
import 'package:sentry/sentry.dart';

Future<void> main() async {
  await Sentry.init(
    (options) {
      options.dsn = 'https://example@sentry.io/example';
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
  runZonedGuarded(() async {
    await Sentry.init(
      (options) {
        options.dsn = 'https://example@sentry.io/example';
      },
    );

    // Init your App.
    initApp();
  }, (exception, stackTrace) async {
    await Sentry.captureException(exception, stackTrace: stackTrace);
  });
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

##### Reporting Bad HTTP Requests as Errors

The `SentryHttpClient` can also catch exceptions that may occur during requests
such as [`SocketException`](https://api.dart.dev/stable/2.13.4/dart-io/SocketException-class.html)s.
This is currently an opt-in feature. The following example shows how to enable it.

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

Furthermore you can track HTTP requests which are considered bad by you.
The following example shows how to do it. It captures exceptions for 
each request with a status code range from 400 to 404 and also for 500.

```dart
import 'package:sentry/sentry.dart';

var client = SentryHttpClient(
  failedRequestStatusCodes: [
    SentryStatusCode.range(400, 404),
    SentryStatusCode(500),
  ],
);

try {
var uriResponse = await client.post('https://example.com/whatsit/create',
     body: {'name': 'doodle', 'color': 'blue'});
 print(await client.get(uriResponse.bodyFields['uri']));
} finally {
 client.close();
}
```

##### Performance Monitoring for HTTP Requests

The `SentryHttpClient` starts a span out of the active span bound to the scope for each HTTP Request. This is currently an opt-in feature. The following example shows how to enable it.

```dart
import 'package:sentry/sentry.dart';

final transaction = Sentry.startTransaction(
  'webrequest',
  'request',
  bindToScope: true,
);

var client = SentryHttpClient();
try {
var uriResponse = await client.post('https://example.com/whatsit/create',
     body: {'name': 'doodle', 'color': 'blue'});
 print(await client.get(uriResponse.bodyFields['uri']));
} finally {
 client.close();
}

await transaction.finish(status: SpanStatus.ok());
```

Read more about [Automatic Instrumentation](https://docs.sentry.io/platforms/dart/performance/instrumentation/automatic-instrumentation/).

##### Tips for catching errors

- Use a `try/catch` block.
- Use a `catchError` block for `Futures`, examples on [dart.dev](https://dart.dev/guides/libraries/futures-error-handling).
- The SDK already runs your `callback` on an error handler, e.g. using [runZonedGuarded](https://api.flutter.dev/flutter/dart-async/runZonedGuarded.html), events caught by the `runZonedGuarded` are captured automatically.
- [Current Isolate errors](https://api.flutter.dev/flutter/dart-isolate/Isolate/addErrorListener.html) which is the equivalent of a main or UI thread, are captured automatically (Only for non-Web Apps).
- For your own `Isolates`, add an [Error Listener](https://api.flutter.dev/flutter/dart-isolate/Isolate/addErrorListener.html) by calling `isolate.addSentryErrorListener()`.

#### Resources

#### Resources

* [![Flutter docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=flutter%20docs)](https://docs.sentry.io/platforms/flutter/)
* [![Dart docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=dart%20docs)](https://docs.sentry.io/platforms/dart/)
* [![Discussions](https://img.shields.io/github/discussions/getsentry/sentry-dart.svg)](https://github.com/getsentry/sentry-dart/discussions)
* [![Discord Chat](https://img.shields.io/discord/621778831602221064?logo=discord&logoColor=ffffff&color=7389D8)](https://discord.gg/PXa5Apfe7K)
* [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](https://stackoverflow.com/questions/tagged/sentry)
* [![Twitter Follow](https://img.shields.io/twitter/follow/getsentry?label=getsentry&style=social)](https://twitter.com/intent/follow?screen_name=getsentry)