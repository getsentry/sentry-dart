### Dart

All you need is the [sentry-dart](https://github.com/getsentry/sentry-dart/tree/main/dart). The `sentry` package doesn't depend on the Flutter SDK.

### Flutter

All you need is the [sentry-flutter](https://github.com/getsentry/sentry-dart/tree/main/flutter) and `sentry-dart` as stated above.

The SDK currently supports Android, iOS and Web. We build the example app for these targets in 3 platforms: Windows, macOS and Linux.
This is to make sure you'd be able to contribute to this project if you're using any of these operating systems.

We also run CI against the Flutter `stable` and `beta` channels so you should be able to build it if you're in one of those.

The Flutter SDK has our Native SDKs embedded, if you wish to learn more about them, they sit at:

[sentry-java](https://github.com/getsentry/sentry-java) for the Android integration.
[sentry-cocoa](https://github.com/getsentry/sentry-cocoa) for the Apple integration.
[sentry-native](https://github.com/getsentry/sentry-native) for the Android NDK integration.

### Dependencies

* The Dart SDK (if you want to change `sentry-dart`)
* The Flutter SDK (if you want to change `sentry-dart` or `sentry-flutter`)
* Android: Android SDK (`sentry-java`) with NDK (`sentry-native`): The example project includes C++.
* iOS: Cocoa SDK (`sentry-cocoa`), you'll need a Mac with xcode installed.
* Web: No additional dependencies.

### Static Code Analysis, Tests, Formatting, Pub Score and Dry publish

* Dar/Flutter
  * Execute `./tool/presubmit.sh` within the `dart` and `flutter` folders
* Swift/CocoaPods
  * Use `swiftlint` and `pod lib lint`
* Kotlin
  * Use `ktlint` and `detekt`
