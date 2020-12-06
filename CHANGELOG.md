# vNext

* Ref: Remove duplicated attachStackTrace field
* Fix: Flutter Configurations should be able to mutate the SentryFlutterOptions
* Enhancement: Add SentryWidgetsBindingObserver, an Integration that captures certain window and device events.
* Enhancement: Set `options.environment` on SDK init based on the flags (kReleaseMode, kDebugMode, kProfileMode or SENTRY_ENVIRONMENT).
* Feature: SentryHttpClient to capture HTTP requests as breadcrumbs
* Ref: Only assign non-null option values in Android native integration in order preserve default values
* Enhancement: Add 'attachThreads' in options. When enabled, threads are attached to all logged events for Android
* Ref: Rename typedef `Logger` to `SentryLogger` to prevent name clashes with logging packages

## Breaking changes

* `Logger` typedef is renamed to `SentryLogger`

# 4.0.0-beta.1

* Fix: StackTrace frames with 'package' uri.scheme are inApp by default #185
* Fix: Missing App's StackTrace frames for Flutter errors
* Enhancement: Add isolateErrorIntegration and runZonedGuardedIntegration to default integrations in sentry-dart
* Fix: Breadcrumb list is a plain list instead of a values list #201
* Ref: Remove deprecated classes (Flutter Plugin for Android) and cleaning up #186
* Fix: Handle immutable event lists and maps
* Fix: NDK integration was being disabled by a typo
* Fix: Missing toList for debug meta #192
* Enhancement: NavigationObserver to record Breadcrumbs for navigation events #197
* Fix: Integrations should be closeable
* Feat: Support split-debug-info for Android #191
* Fix: the event payload must never serialize null or empty fields
* Ref: Make hints optional

## Breaking changes

* `Sentry.init` and `SentryFlutter.init` have an optional callback argument which runs the host App after Sentry initialization.
* `Integration` is an `Interface` instead of a pure Function
* `Hints` are optional arguments
* Sentry Dart SDK adds an `IsolateError` handler by default

# 4.0.0-alpha.2

* Enhancement: `Contexts` were added to the `Scope` #154
* Fix: App. would hang if `debug` mode was enabled and refactoring ##157
* Enhancement: Sentry Protocol v7
* Enhancement: Added missing Protocol fields, `Request`, `SentryStackTrace`...) #155
* Feat: Added `attachStackTrace` options to attach stack traces on `captureMessage` calls
* Feat: Flutter SDK has the Native SDKs embedded (Android and Apple) #158

## Breaking changes

* `Sentry.init` returns a `Future`.
* Dart min. SDK is `2.8.0`
* Flutter min. SDK is `1.17.0`
* Timestamp has millis precision.
* For better groupping, add your own package to the `addInAppInclude` list, e.g.  `options.addInAppInclude('sentry_flutter_example');`
* A few classes of the `Protocol` were renamed.

### Sentry Self Hosted Compatibility

* Since version `4.0.0` of the `sentry_flutter`, `Sentry` version >= `v20.6.0` is required. This only applies to on-premise Sentry, if you are using sentry.io no action is needed.

# `package:sentry` changelog

# 4.0.0-alpha.1

First Release of Sentry's new SDK for Dart/Flutter.

New features not offered by <= v3.0.0:

* Sentry's [Unified API](https://develop.sentry.dev/sdk/unified-api/).
* Complete Sentry [Protocol](https://develop.sentry.dev/sdk/event-payloads/) available.
* Docs and Migration is under review on this [PR](https://github.com/getsentry/sentry-docs/pull/2599)
* For all the breaking changes follow this [PR](https://github.com/getsentry/sentry-dart/pull/117), they'll be soon available on the Migration page.

Packages were released on [pubdev](https://pub.dev/packages/sentry)

We'd love to get feedback and we'll work in getting the GA 4.0.0 out soon.
Until then, the stable SDK offered by Sentry is at version [3.0.1](https://github.com/getsentry/sentry-dart/releases/tag/3.0.1)

# 3.0.1

* Add support for Contexts in Sentry events

# 3.0.0+1

* `pubspec.yaml` and example code clean-up.

# 3.0.0

* Support Web
  * `SentryClient` from `package:sentry/sentry.dart` with conditional import
  * `SentryBrowserClient` for web from `package:sentry/browser_client.dart`
  * `SentryIOClient` for VM and Flutter from `package:sentry/io_client.dart`

# 2.3.1

* Support non-standard port numbers and paths in DSN URL.

# 2.3.0

* Add [breadcrumb](https://docs.sentry.io/development/sdk-dev/event-payloads/breadcrumbs/) support.

# 2.2.0

* Add a `stackFrameFilter` argument to `SentryClient`'s `capture` method (96be842).
* Clean-up code using pre-Dart 2 API (91c7706, b01ebf8).

# 2.1.1

* Defensively copy internal maps event attributes to
  avoid shared mutable state (https://github.com/flutter/sentry/commit/044e4c1f43c2d199ed206e5529e2a630c90e4434)

# 2.1.0

* Support DNS format without secret key.
* Remove dependency on `package:quiver`.
* The `clock` argument to `SentryClient` constructor _should_ now be
  `ClockProvider` (but still accepts `Clock` for backwards compatibility).

# 2.0.2

* Add support for user context in Sentry events.

# 2.0.1

* Invert stack frames to be compatible with Sentry's default culprit detection.

# 2.0.0

* Fixed deprecation warnings for Dart 2
* Refactored tests to work with Dart 2

# 1.0.0

* first and last Dart 1-compatible release (we may fix bugs on a separate branch if there's demand)
* fix code for Dart 2

# 0.0.6

* use UTC in the `timestamp` field

# 0.0.5

* remove sub-seconds from the timestamp

# 0.0.4

* parse and report async gaps in stack traces

# 0.0.3

* environment attributes
* auto-generate event_id and timestamp for events

# 0.0.2

* parse and report stack traces
* use x-sentry-error HTTP response header
* gzip outgoing payloads by default

# 0.0.1

* basic ability to send exception reports to Sentry.io
