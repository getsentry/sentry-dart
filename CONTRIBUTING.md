# Contributing to Sentry Dart & Flutter

Thank you for your interest in contributing to Sentry's Dart and Flutter SDKs! This guide will help
you get started.

## Prerequisites

### Required Tools

* **Dart SDK** - Required for all packages
* **Flutter SDK** - Required for `sentry-flutter` and Flutter integrations
* **[melos](https://melos.invertase.dev/)** - For managing the monorepo

## Environment Setup

### 1. Install melos

```bash
dart pub global activate melos
```

### 2. Bootstrap the project

At the repository root, run:

```bash
melos bootstrap
```

If you're using [fvm](https://fvm.app/), specify the SDK path:

```bash
melos bootstrap --sdk-path=/Users/user/fvm/default/
```

## Project Structure

### Core SDKs

* **[packages/dart](https://github.com/getsentry/sentry-dart/tree/main/packages/dart)** - Core Dart
  SDK (`sentry` package)
* **[packages/flutter](https://github.com/getsentry/sentry-dart/tree/main/packages/flutter)** -
  Flutter SDK (`sentry_flutter` package)

### Integration Packages

Located under `packages/`, we maintain integrations for popular Dart/Flutter libraries:

* **sentry_dio** - HTTP client integration for [dio](https://pub.dev/packages/dio)
* **sentry_logging** - Integration for the [logging](https://pub.dev/packages/logging) package
* **sentry_sqflite** - Integration for [sqflite](https://pub.dev/packages/sqflite) database
* **sentry_drift** - Integration for [drift](https://pub.dev/packages/drift) database
* **sentry_hive** - Integration for [hive](https://pub.dev/packages/hive) database
* **sentry_isar** - Integration for [isar](https://pub.dev/packages/isar) database
* **sentry_file** - File I/O operations integration
* **sentry_link** - GraphQL integration via [gql_link](https://pub.dev/packages/gql_link)
* **sentry_firebase_remote_config** - Integration
  for [firebase_remote_config](https://pub.dev/packages/firebase_remote_config)

## Platform Support

The Flutter SDK supports the following platforms:

* Android
* iOS
* macOS
* Linux
* Windows
* Web

We test the example app on Windows, macOS, and Linux to ensure cross-platform compatibility. CI runs
against Flutter `stable` and `beta` channels.

## Native SDK Dependencies

The Flutter SDK embeds platform-specific native SDKs:

* **Android**: [sentry-java](https://github.com/getsentry/sentry-java) (via
  Gradle) + [sentry-native](https://github.com/getsentry/sentry-native) for NDK
* **iOS/macOS**: [sentry-cocoa](https://github.com/getsentry/sentry-cocoa) (via CocoaPods/SPM)
* **Linux/Windows**: [sentry-native](https://github.com/getsentry/sentry-native) (bundled in
  `packages/flutter/sentry-native/`)
* **Web**: [sentry-javascript](https://github.com/getsentry/sentry-javascript) (loaded via CDN)

[//]: # (TODO: buenaflor - properly set up precommit hooks)
[//]: # (### Static Code Analysis, Tests, Formatting, Pub Score and Dry publish)

[//]: # ()
[//]: # (* Dart/Flutter)

[//]: # (  * Execute `./tool/presubmit.sh` within the `dart` and `flutter` folders)

[//]: # (* Swift/CocoaPods)

[//]: # (  * Use `swiftlint` and `pod lib lint`)

[//]: # (* Kotlin)

[//]: # (  * Use `ktlint` and `detekt`)
