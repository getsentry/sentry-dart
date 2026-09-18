# Manually initialized native SDK replay POC

This proof of concept keeps the native SDK host-owned while routing replay
screenshots through Flutter. Replay records Flutter UI only.

## Android

Install the Flutter replay integration while configuring `SentryAndroid`, before
native integrations are registered:

```kotlin
SentryAndroid.init(applicationContext) { options ->
  options.dsn = "https://examplePublicKey@o0.ingest.sentry.io/0"
  options.sessionReplay.sessionSampleRate = 0.0
  options.sessionReplay.onErrorSampleRate = 0.0
  SentryFlutterPlugin.installReplay(applicationContext, options)
}
```

## iOS

Initialize Sentry Cocoa normally before starting Flutter:

```swift
SentrySDK.start { options in
    options.dsn = "https://examplePublicKey@o0.ingest.sentry.io/0"
    options.sessionReplay.sessionSampleRate = 0
    options.sessionReplay.onErrorSampleRate = 0
}
```

## Flutter

The Flutter SDK attaches its screenshot recorder to the existing native replay
integration when native auto-initialization is disabled:

```dart
await SentryFlutter.init((options) {
  options
    ..dsn = 'https://examplePublicKey@o0.ingest.sentry.io/0'
    ..autoInitializeNativeSdk = false;
});

await SentryFlutter.replay.start();
```

For this POC, native configuration owns replay sampling. Keep the native and
Dart quality settings aligned; Dart owns Flutter screenshot quality, widget
masking, and manual replay controls. One Flutter engine is supported.
