# `package:sentry` and `package:sentry-flutter` changelog

## 4.0.0

- BREAKING CHANGE: Fixed context screenDensity is of type double #53
- BREAKING CHANGE: Fixed context screenDpi is of type int #58
- BREAKING CHANGE: Renamed capture method to captureEvent #64
- BREAKING CHANGE: `package:http` min version bumped to 0.12.0 #104
- BREAKING CHANGE: replace the `package:usage` by `package:uuid` #94
- BREAKING CHANGE: `Event.message` must now be an instance of `Message`
- BREAKING CHANGE: SentryClient must now be initialized with a SentryOptions #118
- By default no logger it set #63
- Added missing Contexts to Event.copyWith() #62 
- remove the `package:args` dependency #94
- move the `package:pedantic` to dev depencies #94
- Added GH Action Changelog verifier #95
- Added GH Action (CI) for Dart #97
- new Dart code file structure #96 
- Base the sdk name on the platform (`sentry.dart` for io & flutter, `sentry.dart.browser` in a browser context) #103 
- Single changelog and readme for both packages #105
- new static API : Sentry.init(), Sentry.captureEvent() #108
- expect a sdkName based on the test platform #105
- Added Scope and Breadcrumb ring buffer #109
- Added Hub to SDK #113
- Ref: Hub passes the Scope to SentryClient #114
- Feature: sentry options #116
- Ref: SentryId generates UUID #119
- Ref: Event now is SentryEvent and added GPU #121
- Feat: before breadcrumb and scope ref. #122
- Ref: Sentry init with null and empty DSN and close method #126
- Ref: Hint is passed across Sentry static class, Hub and Client #124
- Ref: Remove stackFrameFilter in favor of beforeSendCallback #125
- Ref: added Transport #123
- Feat: apply sample rate
- Ref: execute before send callback
- Feat: add lastEventId to the Sentry static API
- Feat: addBreadcrumb on Static API
- Add a Dart web example
- Fix: Integrations are executed on Hub creation
- Fix: NoOp encode for Web
- Fix: Breadcrumb data should accept serializable types and not only String values
- Ref: added Scope.applyToEvent

# `package:sentry` changelog

## 3.0.1

- Add support for Contexts in Sentry events

## 3.0.0+1

- `pubspec.yaml` and example code clean-up.

## 3.0.0

- Support Web
  - `SentryClient` from `package:sentry/sentry.dart` with conditional import
  - `SentryBrowserClient` for web from `package:sentry/browser_client.dart`
  - `SentryIOClient` for VM and Flutter from `package:sentry/io_client.dart`

## 2.3.1

- Support non-standard port numbers and paths in DSN URL.

## 2.3.0

- Add [breadcrumb](https://docs.sentry.io/development/sdk-dev/event-payloads/breadcrumbs/) support.

## 2.2.0

- Add a `stackFrameFilter` argument to `SentryClient`'s `capture` method (96be842).
- Clean-up code using pre-Dart 2 API (91c7706, b01ebf8).

## 2.1.1

- Defensively copy internal maps event attributes to
  avoid shared mutable state (https://github.com/flutter/sentry/commit/044e4c1f43c2d199ed206e5529e2a630c90e4434)

## 2.1.0

- Support DNS format without secret key.
- Remove dependency on `package:quiver`.
- The `clock` argument to `SentryClient` constructor _should_ now be
  `ClockProvider` (but still accepts `Clock` for backwards compatibility).

## 2.0.2

- Add support for user context in Sentry events.

## 2.0.1

- Invert stack frames to be compatible with Sentry's default culprit detection.

## 2.0.0

- Fixed deprecation warnings for Dart 2
- Refactored tests to work with Dart 2

## 1.0.0

- first and last Dart 1-compatible release (we may fix bugs on a separate branch if there's demand)
- fix code for Dart 2

## 0.0.6

- use UTC in the `timestamp` field

## 0.0.5

- remove sub-seconds from the timestamp

## 0.0.4

- parse and report async gaps in stack traces

## 0.0.3

- environment attributes
- auto-generate event_id and timestamp for events

## 0.0.2

- parse and report stack traces
- use x-sentry-error HTTP response header
- gzip outgoing payloads by default

## 0.0.1

- basic ability to send exception reports to Sentry.io
