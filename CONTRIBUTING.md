# Contributing to Sentry Dart & Flutter

Thank you for your interest in contributing to Sentry's Dart and Flutter SDKs! This guide will help
you get started.

## Prerequisites

### Required Tools

* **Dart SDK** `>=3.5.0` - Required for all packages
* **Flutter SDK** `>=3.24.0` - Required for `sentry-flutter` and Flutter integrations
* **[fvm](https://fvm.app/)** - For Flutter/Dart version management
* **[melos](https://melos.invertase.dev/)** - For managing the monorepo

## Environment Setup

### 1. Install fvm and melos

```bash
dart pub global activate fvm
dart pub global activate melos
```

### 2. Install the Flutter SDK via fvm

```bash
fvm use stable
```

This reads `.fvmrc` and installs the pinned Flutter version. It also creates a `.fvm/flutter_sdk`
symlink that melos uses to resolve `dart`/`flutter` commands (via `sdkPath` in `melos.yaml`).

### 3. Bootstrap the project

```bash
melos bootstrap
```

This resolves all package dependencies and configures git hooks for pre-commit checks.

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

## Pre-commit Hooks

After `melos bootstrap`, git is configured to use `.githooks/` for hooks. The pre-commit hook
automatically runs static analysis and formatting checks before each commit:

```bash
melos run precommit
```

This runs `analyze:dart`, `analyze:flutter`, and `format:check` across all packages.

To run the full suite including tests:

```bash
melos run precommit:full
```

### Available Scripts

| Script | Description |
|--------|-------------|
| `melos run analyze:dart` | Run `dart analyze` on Dart-only packages |
| `melos run analyze:flutter` | Run `flutter analyze` on Flutter packages |
| `melos run format:check` | Check formatting across all packages |
| `melos run test:dart` | Run tests for Dart-only packages |
| `melos run test:flutter` | Run tests for Flutter packages |
| `melos run precommit` | Run analysis + format checks |
| `melos run precommit:full` | Run analysis + format checks + tests |
