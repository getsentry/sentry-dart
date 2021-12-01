# Unreleased

* Feat: Auto Transactions (#643)
* Feat: Add logger name to `SentryLogger` and send errors in integrations to the registered logger (#641)

# 6.1.2

* Fix: Remove is Enum check to support older Dart versions (#635)

# 6.1.1

* Fix: Transaction serialization if not encodable (#633)

# 6.1.0

* Bump: Sentry-Android to 5.3.0 and Sentry-Cocoa to 7.5.1 (#629)
* Fix: event.origin tag for macOS and other Apple platforms (#622)
* Feat: Add current route as transaction (#615)
* Feat: Add Breadcrumbs for Flutters `debugPrint` (#618)
* Feat: Enrich Dart context with isolate name (#600)
* Feat: Sentry Performance for HTTP client (#603)
* Performance API for Dart/Flutter (#530)

## Breaking Changes:

* `SentryEvent` inherits from the `SentryEventLike` mixin
* `Scope#transaction` sets and reads from the `Scope#span` object if bound to the Scope

# 6.1.0-beta.1

* Feat: Add current route as transaction (#615)
* Feat: Add Breadcrumbs for Flutters `debugPrint` (#618)

# 6.1.0-alpha.2

* Bump Sentry Android SDK to [5.2.0](https://github.com/getsentry/sentry-dart/pull/594) (#594)
  - [changelog](https://github.com/getsentry/sentry-java/blob/5.2.0/CHANGELOG.md)
  - [diff](https://github.com/getsentry/sentry-java/compare/5.1.2...5.2.0)
* Feat: Enrich Dart context with isolate name (#600)
* Feat: Sentry Performance for HTTP client (#603)

# 6.1.0-alpha.1

* Performance API for Dart/Flutter (#530)

## Breaking Changes:

* `SentryEvent` inherits from the `SentryEventLike` mixin
* `Scope#transaction` sets and reads from the `Scope#span` object if bound to the Scope

# 6.0.1

* Fix: Set custom SentryHttpClientError when HTTP error is captured without an exception (#580)
* Bump: Android AGP 4.1 (#586)
* Bump: Sentry Cocoa to 7.3.0 (#589)

# 6.0.0

* Fix: Update `SentryUser` according to docs (#561)
* Feat: Enable or disable reporting of packages (#563)
* Bump: Sentry-Cocoa to 7.2.7 (#578)
* Bump: Sentry-Android to 5.1.2 (#578)
* Fix: Read Sentry config from environment variables as fallback (#567)

# 6.0.0-beta.4

## Breaking Changes:

* Feat: Lists of exceptions and threads (#524)
* Feat: Collect more information for exceptions collected via `FlutterError.onError` (#538)
* Feat: Add maxAttachmentSize option (#553)
* Feat: HTTP breadcrumbs have the request & response size if available (#552)

# 6.0.0-beta.3

* Fix: Re-initialization of Flutter SDK (#526)
* Enhancement: Call `toString()` on all non-serializable fields (#528)
* Fix: Always call `Flutter.onError` in order to not swallow messages (#533)
* Bump: Android SDK to 5.1.0-beta.6 (#535)

# 6.0.0-beta.2

* Fix: Serialization of Flutter Context (#520)
* Feat: Add support for attachments (#505)
* Feat: Add support for User Feedback (#506)

# 6.0.0-beta.1

* Feat: Browser detection (#502)
* Feat: Enrich events with more context (#452)
* Feat: Add Culture Context (#491)
* Feat: Add DeduplicationEventProcessor (#498)
* Feat: Capture failed requests as event (#473)
* Feat: `beforeSend` callback accepts async code (#494)

## Breaking Changes:

* Ref: EventProcessor changed to an interface (#489)
* Feat: Support envelope based transport for events (#391)
  * The method signature of `Transport` changed from `Future<SentryId> send(SentryEvent event)` to `Future<SentryId> send(SentryEnvelope envelope)`
* Remove `Sentry.currentHub` (#490)
* Ref: Rename `cacheDirSize` to `maxCacheItems` and add `maxCacheItems` for iOS (#495)
* Ref: Add error and stacktrace parameter to logger (#503)
* Feat: Change timespans to Durations in SentryOptions (#504)
* Feat: `beforeSend` callback accepts async code (#494)

## Sentry Self Hosted Compatibility

* Since version `6.0.0` of the `sentry`, [Sentry's version >= v20.6.0](https://github.com/getsentry/self-hosted/releases) is required. This only applies to on-premise Sentry, if you are using sentry.io no action is needed.

# 5.1.0

* Fix: Merge user from event and scope (#467)
* Feature: Allow setting of default values for in-app-frames via `SentryOptions.considerInAppFramesByDefault` (#482)
* Bump: sentry-android to v5.0.1 (#486)
* Bump: Sentry-Cocoa to 7.1.3 for iOS and macOS (#488)

# 5.1.0-beta.1

* Fix: `Sentry.close()` closes native SDK integrations (#388)
* Feat: Support for macOS (#389)
* Feat: Support for Linux (#402)
* Feat: Support for Windows (#407)
* Fix: Mark `Sentry.currentHub` as deprecated (#406)
* Fix: Set console logger as default logger in debug mode (#413)
* Fix: Use name from pubspec.yaml for release if package id is not available (#411)
* Feat: `SentryHttpClient` tracks the duration which a request takes and logs failed requests (#414)
* Bump: sentry-cocoa to v7.0.0 (#424)
* Feat: Support for Out-of-Memory-Tracking on macOS/iOS (#424)
* Fix: Trim `\u0000` from Windows package info (#420)
* Feature: Log calls to `print()` as Breadcrumbs (#439)
* Fix: `dist` was read from `SENTRY_DSN`, now it's read from `SENTRY_DIST` (#442)
* Bump: sentry-cocoa to v7.0.3 (#445)
* Fix: Fix adding integrations on web (#450)
* Fix: Use `log()` instead of `print()` for SDK logging (#453)
* Bump: sentry-android to v5.0.0-beta.2 (#457)
* Feature: Add `withScope` callback to capture methods (#463)
* Fix: Add missing properties `language`, `screenHeightPixels` and `screenWidthPixels` to `SentryDevice` (#465)

## Sentry Self Hosted Compatibility

* This version of the `sentry` Dart package requires [Sentry server >= v20.6.0](https://github.com/getsentry/self-hosted/releases). This only applies to on-premise Sentry, if you are using sentry.io no action is needed.

# 5.0.0

* Sound null safety
* Fix: event.origin and event.environment tags have wrong value for iOS (#365) and (#369)
* Fix: Fix deprecated `registrar.messenger` call in `SentryFlutterWeb` (#364)
* Fix: Enable breadcrumb recording mechanism based on platform (#366)
* Feat: Send default PII options (#360)
* Bump: sentry-cocoa to v6.2.1 (#360)
* Feat: Migration from `package_info` to `package_info_plus` plugin (#370)
* Fix: Set `SentryOptions.debug` in `sentry` (#376)
* Fix: Read all environment variables in `sentry` (#375)

## Breaking Changes:

* Return type of `Sentry.close()` changed from `void` to `Future<void>` and `Integration.close()` changed from `void` to `FutureOr<void>` (#395)
* Remove deprecated member `enableLifecycleBreadcrumbs`. Use `enableAppLifecycleBreadcrumbs` instead. (#366)

# 4.1.0-nullsafety.1

* Bump: sentry-android to v4.3.0 (#343)
* Fix: Multiple FlutterError.onError calls in FlutterErrorIntegration (#345)
* Fix: Pass hint to EventProcessors (#356)
* Fix: EventProcessors were not dropping events when returning null (#353)

## Breaking Changes:

* Fix: Plugin Registrant class moved to barrel file (#358)
  * This changed the import from `import 'package:sentry_flutter/src/sentry_flutter_web.dart';` 
    to `import 'package:sentry_flutter/sentry_flutter_web.dart';`
  * This could lead to breaking changes. Typically it shouldn't because the referencing file is auto-generated.
* Fix: Prefix classes with Sentry (#357)
  * A couple of classes were often conflicting with user's code.
    Thus this change renames the following classes:
    * `App` -> `SentryApp`
    * `Browser` -> `SentryBrowser`
    * `Device` -> `SentryDevice`
    * `Gpu` -> `SentryGpu`
    * `Integration` -> `SentryIntegration`
    * `Message` -> `SentryMessage`
    * `OperatingSystem` -> `SentryOperatingSystem`
    * `Request` -> `SentryRequest`
    * `User` -> `SentryUser`
    * `Orientation` -> `SentryOrientation`

# 4.1.0-nullsafety.0

* Fix: Do not append stack trace to the exception if there are no frames
* Fix: Empty DSN disables the SDK and runs the App
* Feat: sentry and sentry_flutter null-safety thanks to @ueman and @fzyzcjy

# 4.0.6

* Fix: captureMessage defaults SentryLevel to info
* Fix: SentryEvent.throwable returns the unwrapped throwable instead of the throwableMechanism
* Feat: Support enableNativeCrashHandling on iOS

# 4.0.5

* Bump: sentry-android to v4.0.0
* Fix: Pana Flutter upper bound deprecation
* Fix: sentry_flutter static analysis (pana) using stable version

# 4.0.4

* Fix: Call WidgetsFlutterBinding.ensureInitialized() within runZoneGuarded

# 4.0.3

* Fix: Auto session tracking start on iOS #274
* Bump: Sentry-cocoa to 6.1.4

# 4.0.2

* Fix: Mark session as `errored` in iOS #270
* Fix: Pass auto session tracking interval to iOS
* Fix: Deprecated binaryMessenger (MethodChannel member) for Flutter Web
* Ref: Make `WidgetsFlutterBinding.ensureInitialized();` the first thing the Sentry SDK calls.
* Bump: Sentry-cocoa to 6.0.12
* Feat: Respect FlutterError silent flag #248
* Bump: Android SDK to v3.2.1 #273

# 4.0.1

* Ref: Changed category of Flutter lifecycle tracking [#240](https://github.com/getsentry/sentry-dart/issues/240)
* Fix: Envelope length should be based on the UTF8 array instead of String length

# 4.0.0

Release of Sentry's new SDK for Dart/Flutter.

New features not offered by <= v4.0.0:

## Dart SDK

* Sentry's [Unified API](https://develop.sentry.dev/sdk/unified-api/).
* Complete Sentry's [Protocol](https://develop.sentry.dev/sdk/event-payloads/) available.
* [Dart SDK](https://docs.sentry.io/platforms/dart/) docs.
* Automatic [HTTP Breadcrumbs](https://docs.sentry.io/platforms/dart/usage/advanced-usage/#automatic-breadcrumbs) for [http.Client](https://pub.dev/documentation/http/latest/http/Client-class.html)
* No boilerplate for `runZonedGuarded` and `Isolate.current.addErrorListener`
* All events are enriched with [Scope's Contexts](https://develop.sentry.dev/sdk/event-payloads/#scope-interfaces), this includes Breadcrumbs, tags, User, etc...

## Flutter SDK

* The Flutter SDK is built on top of the Dart SDK, so it includes all the available features, plus
* [Flutter SDK](https://docs.sentry.io/platforms/flutter/) docs.
* Automatic [NavigatorObserver Breadcrumbs](https://docs.sentry.io/platforms/flutter/usage/advanced-usage/#automatic-breadcrumbs)
* Automatic [Device's Breadcrumbs](https://docs.sentry.io/platforms/flutter/usage/advanced-usage/#automatic-breadcrumbs) through the Android and iOS SDKs or via Sentry's `WidgetsBindingObserver` wrapper
* No boilerplate for `FlutterError.onError`
* All events are enriched with [Contexts's data](https://develop.sentry.dev/sdk/event-payloads/contexts/), this includes Device's, OS, App info, etc...
* Offline caching
* [Release health](https://docs.sentry.io/product/releases/health/)
* Captures not only Dart and Flutter errors, but also errors caused on the native platforms, Like Kotlin, Java, C and C++ for Android and Swift, ObjC, C, C++ for iOS
* Supports Fatal crashes, Event is going to be sent on App's restart
* Supports `split-debug-info` for Android only
* Flutter Android, iOS and limited support for Flutter Web

Improvements:

* Feat: Added a copyWith method to all the protocol classes

Packages were released on [sentry pubdev](https://pub.dev/packages/sentry) and [sentry_flutter pubdev](https://pub.dev/packages/sentry_flutter)

## Sentry Self Hosted Compatibility

* Since version `4.0.0` of the `sentry_flutter`, [Sentry's version >= v20.6.0](https://github.com/getsentry/self-hosted/releases) is required. This only applies to on-premise Sentry, if you are using sentry.io no action is needed.

# 4.0.0-beta.2

* Ref: Remove duplicated attachStackTrace field
* Fix: Flutter Configurations should be able to mutate the SentryFlutterOptions
* Enhancement: Add SentryWidgetsBindingObserver, an Integration that captures certain window and device events.
* Enhancement: Set `options.environment` on SDK init based on the flags (kReleaseMode, kDebugMode, kProfileMode or SENTRY_ENVIRONMENT).
* Feature: SentryHttpClient to capture HTTP requests as breadcrumbs
* Ref: Only assign non-null option values in Android native integration in order preserve default values
* Enhancement: Add 'attachThreads' in options. When enabled, threads are attached to all logged events for Android
* Ref: Rename typedef `Logger` to `SentryLogger` to prevent name clashes with logging packages
* Fix: Scope Event processors should be awaited
* Fix: Package usage as git dependency

## Breaking changes

* `Logger` typedef is renamed to `SentryLogger`
* `attachStackTrace` is renamed to `attachStacktrace`

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

New features not offered by <= v4.0.0:

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
