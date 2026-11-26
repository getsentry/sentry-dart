# Changelog

## 10.7.0

### Features

- Track slow and frozen frames and frames delay on Flutter Web, measured against a 60 Hz display by @Ortes and @buenaflor in [#4165](https://github.com/getsentry/sentry-dart/pull/4165)
- Add `SentryFlutter.replay.pauseTouchTracking()` and `resumeTouchTracking()` to stop recording touch positions on sensitive screens, such as a custom PIN pad, while the masked screen recording continues. Touch tracking stays paused across new replays and after `resume()` until `resumeTouchTracking()` is called. Code that implements `SentryReplay` must add the two methods by @romtsn, @claude and @buenaflor in [#4166](https://github.com/getsentry/sentry-dart/pull/4166)
- Link errors to their own streamed span by @buenaflor in [#4173](https://github.com/getsentry/sentry-dart/pull/4173)

### Fixes

- Spans that ended before frame tracking resumed no longer report estimated frame metrics by @Ortes and @buenaflor in [#4200](https://github.com/getsentry/sentry-dart/pull/4200)

### Dependencies

#### Deps

- chore(deps): update Android SDK to v8.66.0 by @buenaflor with @github-actions in [#4226](https://github.com/getsentry/sentry-dart/pull/4226)
- chore(deps): update Cocoa SDK to v9.36.0 by @github-actions in [#4227](https://github.com/getsentry/sentry-dart/pull/4227)
- chore(deps): update JavaScript SDK to v11.17.0 by @buenaflor with @github-actions in [#4195](https://github.com/getsentry/sentry-dart/pull/4195)
- chore(deps): update Native SDK to v0.17.7 by @buenaflor with @github-actions in [#4206](https://github.com/getsentry/sentry-dart/pull/4206)

### Internal Changes

- (craft) Re-enable pub.dev publish validation by @buenaflor with @sentry-junior in [#4230](https://github.com/getsentry/sentry-dart/pull/4230)
- (flutter) Drop unneeded Material imports by @buenaflor with @sentry-junior in [#4201](https://github.com/getsentry/sentry-dart/pull/4201)
- (ios) Build TestFlight sample with Xcode 27 by @philprime with @sentry-junior in [#4196](https://github.com/getsentry/sentry-dart/pull/4196)
- Skip unaffected platform jobs and tidy check names by @buenaflor with @sentry-junior in [#4228](https://github.com/getsentry/sentry-dart/pull/4228)
- Run JavaScript SDK updater weekly by @buenaflor with @sentry-junior in [#4208](https://github.com/getsentry/sentry-dart/pull/4208)
- Remove Cursor Bugbot review guidelines by @antonis with @sentry-junior in [#4205](https://github.com/getsentry/sentry-dart/pull/4205)
## 10.6.0

### Features

- Windows: run sentry-native init, scope sync and close on a background worker so they no longer freeze the app window or delay the first frame. by @palmoni5 and @Y-PLONI in [#4094](https://github.com/getsentry/sentry-dart/pull/4094)

### Fixes

#### Flutter

- Add Dart app debug image on Android by @buenaflor with @sentry-junior in [#4194](https://github.com/getsentry/sentry-dart/pull/4194)
- Cap iOS fallback refresh rate at 60Hz by @buenaflor with @sentry-junior in [#4192](https://github.com/getsentry/sentry-dart/pull/4192)

#### Other

- (dart) Add status to streaming trace context by @buenaflor with @sentry-junior in [#4193](https://github.com/getsentry/sentry-dart/pull/4193)
- (native) Fall back to XDG cache dir on Linux by @yeegz and @buenaflor in [#4189](https://github.com/getsentry/sentry-dart/pull/4189)
- (replay) Route network detail through sentry-java's own hint by @hkarmoush and @buenaflor in [#3980](https://github.com/getsentry/sentry-dart/pull/3980)

### Dependencies

#### Deps

- chore(deps): update JavaScript SDK to v11.14.0 by @github-actions in [#4183](https://github.com/getsentry/sentry-dart/pull/4183)
- chore(deps): update Android SDK to v8.65.0 by @github-actions in [#4184](https://github.com/getsentry/sentry-dart/pull/4184)
## 10.5.0

### Fixes

#### Flutter

- Parent HTTP spans to the new route after navigating away from the initial route, instead of to the app-start `root /` transaction until its TTFD timeout (#4154) by @buenaflor, @codex and 2 others in [#4155](https://github.com/getsentry/sentry-dart/pull/4155)
- `pushReplacement`/`replace` of the current route now starts a `ui.load` transaction (static) or route span (streaming), like `push` by @buenaflor, @codex and 2 others in [#4155](https://github.com/getsentry/sentry-dart/pull/4155)
- With `enableAutoTransactions` disabled, navigating to a named route now ends the app-start display (TTID/TTFD end as `deadline_exceeded` in static mode), so spans from later screens no longer attach to the app start by @buenaflor, @codex and 2 others in [#4155](https://github.com/getsentry/sentry-dart/pull/4155)
- Use a writable native database directory on Windows when `nativeDatabasePath` isn't set, so native crashes from packaged (MSIX/Microsoft Store) apps are captured. by @lucas-zimerman and @claude in [#4156](https://github.com/getsentry/sentry-dart/pull/4156)

#### Other

- (dart) Avoid mutating flags of captured events by @buenaflor and @claude in [#4169](https://github.com/getsentry/sentry-dart/pull/4169)

### Dependencies

#### Deps

- chore(deps): update JavaScript SDK to v11.13.0 by @buenaflor with @github-actions in [#4177](https://github.com/getsentry/sentry-dart/pull/4177)
- chore(deps): update Cocoa SDK to v9.35.0 by @github-actions in [#4176](https://github.com/getsentry/sentry-dart/pull/4176)

### Internal Changes

- (agents) Disable AI attribution in commits by @buenaflor with @sentry-junior in [#4170](https://github.com/getsentry/sentry-dart/pull/4170)
- (android) Upgrade Flutter example toolchain by @buenaflor in [#4171](https://github.com/getsentry/sentry-dart/pull/4171)
## 10.4.0

### Fixes

- (flutter) Fetch sentry-native as a release zip on Windows by @lucas-zimerman and @claude in [#4110](https://github.com/getsentry/sentry-dart/pull/4110)
- (link) Set span attributes on creation by @awishere, @codex and @buenaflor in [#4044](https://github.com/getsentry/sentry-dart/pull/4044)
- (replay) Mask correctly during zoom page transitions by @lucas-zimerman, @claude and @buenaflor in [#4130](https://github.com/getsentry/sentry-dart/pull/4130)

### Enhancements

- Lower the minimum Android SDK version for Flutter from API 26 to API 24, matching Flutter's default `minSdk`. by @buenaflor and @lucas-zimerman with @sentry-junior in [#4150](https://github.com/getsentry/sentry-dart/pull/4150)

### Dependencies

#### Deps

- chore(deps): update JavaScript SDK to v11.12.0 by @buenaflor and @codex with @github-actions in [#4161](https://github.com/getsentry/sentry-dart/pull/4161)
- chore(deps): update Cocoa SDK to v9.34.0 by @buenaflor and @codex with @github-actions in [#4162](https://github.com/getsentry/sentry-dart/pull/4162)
- chore(deps): update Android SDK to v8.64.0 by @buenaflor and @codex with @github-actions in [#4163](https://github.com/getsentry/sentry-dart/pull/4163)
- chore(deps): update Native SDK to v0.17.6 by @buenaflor with @github-actions in [#4144](https://github.com/getsentry/sentry-dart/pull/4144)

### Internal Changes

- (release) Bump craft to 3.9.0 and update config by @BYK with @sentry-junior in [#4140](https://github.com/getsentry/sentry-dart/pull/4140)
- (warden) Enable incremental review by @Jeffreyhung with @sentry-junior in [#4145](https://github.com/getsentry/sentry-dart/pull/4145)
- Ask Junior to recheck native SDK bumps by @buenaflor with @sentry-junior in [#4149](https://github.com/getsentry/sentry-dart/pull/4149)
- Expand platform and tooling ignore rules by @philprime in [#4148](https://github.com/getsentry/sentry-dart/pull/4148)
- Point Sentry Conventions links to conventions.sentry.dev by @cleptric and @claude in [#4146](https://github.com/getsentry/sentry-dart/pull/4146)
## 10.3.0

### Features

#### Flutter

- Add experimental Session Replay support for Flutter Web with widget masking. Opt in with `options.replay.enableWebReplay = true` along with `replay.sessionSampleRate` or `replay.onErrorSampleRate`. Requires the CanvasKit or Skwasm renderer. `SentryFlutter.replay` start/stop/flush also work on web, and the Dart scope (user, tags, extras, contexts, breadcrumbs) now syncs to the JS SDK on web ([#2897](https://github.com/getsentry/sentry-dart/issues/2897)) by @lucas-zimerman in [#4059](https://github.com/getsentry/sentry-dart/pull/4059)
- Add `addUserInteractionWidget` to `SentryFlutterOptions` to track taps on widgets the SDK doesn't recognize, like those from `material_ui` and `cupertino_ui`. Tooltip labels now come from `RawTooltip`, so `material_ui` tooltips get labels too. by @dawid-niedzwiecki in [#4069](https://github.com/getsentry/sentry-dart/pull/4069)

### Fixes

- (dart) Count streamed spans in client reports by @sentry-junior in [#4097](https://github.com/getsentry/sentry-dart/pull/4097)
- (flutter) Use static SwiftPM binaries by @philprime in [#4118](https://github.com/getsentry/sentry-dart/pull/4118)

### Dependencies

#### Deps

- chore(deps): update Cocoa SDK to v9.32.0 by @github-actions in [#4128](https://github.com/getsentry/sentry-dart/pull/4128)
- chore(deps): update Native SDK to v0.17.5 by @github-actions in [#4127](https://github.com/getsentry/sentry-dart/pull/4127)
- chore(deps): update Android SDK to v8.62.0 by @github-actions in [#4124](https://github.com/getsentry/sentry-dart/pull/4124)

### Internal Changes

- (flutter) Use Cocoa internal serializer by @philprime in [#4100](https://github.com/getsentry/sentry-dart/pull/4100)
- Use dark-mode-aware Sentry logo in READMEs by @sentry-junior in [#4123](https://github.com/getsentry/sentry-dart/pull/4123)
## 10.2.0

### Features

- Report the generation of the cellular network technology in `device.connection_effective_type` on Android and iOS, for example `4g` or `5g`. On Android 11 and earlier, the app must have the `READ_PHONE_STATE` permission. by @alwx in [#4066](https://github.com/getsentry/sentry-dart/pull/4066)

### Fixes

#### Flutter

- Support JNI 1.1 by @Carapacik in [#4099](https://github.com/getsentry/sentry-dart/pull/4099)
- Allow empty associatedEventId in SentryFeedbackForm by @lucas-zimerman in [#4108](https://github.com/getsentry/sentry-dart/pull/4108)

#### Other

- (ios) Avoid deprecated windows in refresh rate by @ananyateklu in [#4111](https://github.com/getsentry/sentry-dart/pull/4111)

### Dependencies

#### Deps

- chore(deps): update Android SDK to v8.61.1 by @github-actions in [#4114](https://github.com/getsentry/sentry-dart/pull/4114)
- chore(deps): update Cocoa SDK to v9.31.0 by @github-actions in [#4112](https://github.com/getsentry/sentry-dart/pull/4112)
- chore(deps): update Native SDK to v0.17.4 by @github-actions in [#4093](https://github.com/getsentry/sentry-dart/pull/4093)

### Internal Changes

- Pin Java 17 for Android updater by @buenaflor in [#4113](https://github.com/getsentry/sentry-dart/pull/4113)
## 10.1.0

### Features

- Session Replays on iOS now include trace IDs, so they can be found by searching for a trace ID in Sentry by @antonis in [#4083](https://github.com/getsentry/sentry-dart/pull/4083)

### Fixes

- Deobfuscate the Java frames of Dart-captured `PlatformException` events on Android by attaching the ProGuard debug image, and keep existing debug images when loading native ones. by @xelarich in [#4081](https://github.com/getsentry/sentry-dart/pull/4081)
- (app-start) Keep builds and deduplicate TTFD by @buenaflor in [#4079](https://github.com/getsentry/sentry-dart/pull/4079)
- (flutter) Don't report feedback success when send fails by @lucas-zimerman in [#4043](https://github.com/getsentry/sentry-dart/pull/4043)
- (replay) Link errors to manual replays by @buenaflor in [#4078](https://github.com/getsentry/sentry-dart/pull/4078)

### Dependencies

#### Deps

- chore(deps): update Android SDK to v8.61.0 by @github-actions in [#4090](https://github.com/getsentry/sentry-dart/pull/4090)
- chore(deps): update Cocoa SDK to v9.30.2 by @github-actions in [#4089](https://github.com/getsentry/sentry-dart/pull/4089)
- chore(deps): update Native SDK to v0.17.3 by @github-actions in [#4082](https://github.com/getsentry/sentry-dart/pull/4082)

### Internal Changes

- Remove Collect App Metrics jobs by @buenaflor in [#4091](https://github.com/getsentry/sentry-dart/pull/4091)
## 10.0.0

Version 10.0.0 marks a major release of the Sentry Dart/Flutter SDKs containing breaking changes.

### How To Upgrade

Please carefully read through the migration guide in the Sentry docs on how to upgrade from version 9 to version 10
 - [Flutter migration guide](https://docs.sentry.io/platforms/dart/guides/flutter/migration/v9-to-v10/)

### Breaking Changes

- Default to streaming traces (`SentryTraceLifecycle.stream`), sending spans as they finish. Use `Sentry.startSpan` instead of `Sentry.startTransaction` and `ISentrySpan.startChild`, which are no-ops in streaming mode. Set `options.traceLifecycle = SentryTraceLifecycle.static` to keep using the transaction APIs. ([#4057](https://github.com/getsentry/sentry-dart/pull/4057))
- Require Dart 3.12.0 or newer and Flutter 3.44.0 or newer. ([#3784](https://github.com/getsentry/sentry-dart/pull/3784), [98581ac](https://github.com/getsentry/sentry-dart/commit/98581ac53))
- Raise the minimum Android SDK version for Flutter from API 21 to API 26. Set your app's Android `minSdk` to 26 or higher. ([#4049](https://github.com/getsentry/sentry-dart/pull/4049))
- Remove CocoaPods support. Flutter apps targeting Apple platforms must use Swift Package Manager. ([#3879](https://github.com/getsentry/sentry-dart/pull/3879))
- Remove `enableLogs` and `enableMetrics`. Logs and metrics are always enabled. The logging integration forwards Sentry logs by default; adjust `minSentryLogLevel` or set it to `Level.OFF` to disable forwarding. ([#3983](https://github.com/getsentry/sentry-dart/pull/3983))
- Remove `enableStandaloneAppStartTracing`. When tracing is enabled, app start is always reported as a standalone `app.start` root on Android and iOS. ([#3981](https://github.com/getsentry/sentry-dart/pull/3981))
- Make native failed-request capture opt-in. ([#3885](https://github.com/getsentry/sentry-dart/pull/3885))
- Run error sampling after event processors and `beforeSend`. These callbacks now also run for events that are subsequently sampled out. ([#3955](https://github.com/getsentry/sentry-dart/pull/3955))
- Require `traceId` on `SentryLog`, make logger methods return `void`, and remove `SentryLogAttribute`. ([#3842](https://github.com/getsentry/sentry-dart/pull/3842), [#3852](https://github.com/getsentry/sentry-dart/pull/3852), [#3843](https://github.com/getsentry/sentry-dart/pull/3843))
- Add a `Hint` parameter to the before-send callbacks for logs, metrics, and spans. ([#3847](https://github.com/getsentry/sentry-dart/pull/3847))
- Make feature flags hub/scope-based. ([#3848](https://github.com/getsentry/sentry-dart/pull/3848))
- Remove SDK profiling and deprecated performance collectors. ([#3891](https://github.com/getsentry/sentry-dart/pull/3891), [#3850](https://github.com/getsentry/sentry-dart/pull/3850))
- Remove deprecated `copyWith` APIs and protocol clones, and make `clone()` internal. ([#3877](https://github.com/getsentry/sentry-dart/pull/3877), [#3845](https://github.com/getsentry/sentry-dart/pull/3845))
- Remove the deprecated `SentryFeedbackWidget`. ([#3844](https://github.com/getsentry/sentry-dart/pull/3844))
- Replace `options.log` with internal logging and make `BindingWrapper` and `bindingUtils` internal. ([#3932](https://github.com/getsentry/sentry-dart/pull/3932), [#3940](https://github.com/getsentry/sentry-dart/pull/3940))
- Align span attributes with Sentry Conventions and remove `file.async` from file instrumentation. ([#3805](https://github.com/getsentry/sentry-dart/pull/3805), [#3841](https://github.com/getsentry/sentry-dart/pull/3841))
- Use Breakpad as the default native crash backend on Windows and Linux. ([#4045](https://github.com/getsentry/sentry-dart/pull/4045))

### Features

- Add manual Session Replay controls on Android and iOS through `SentryFlutter.replay`: `start`, `startBuffering`, `pause`, `resume`, `stop`, and `flush`. Explicitly started replays work even when both automatic sample rates are `0`. ([#4010](https://github.com/getsentry/sentry-dart/pull/4010))
- Improve startup frame spans, and remove the pre-init and Sentry initialization spans from startup traces. ([#4018](https://github.com/getsentry/sentry-dart/pull/4018), [6aad048](https://github.com/getsentry/sentry-dart/commit/6aad0486c))
- Include sampled-out errors in release health, and report unhandled Flutter errors as unhandled sessions rather than crashes. ([#4008](https://github.com/getsentry/sentry-dart/pull/4008), [#4007](https://github.com/getsentry/sentry-dart/pull/4007))
- Mask `SensitiveContent` by default in Session Replay. ([#3973](https://github.com/getsentry/sentry-dart/pull/3973))
- Graduate mature v10 APIs from experimental status. ([#3940](https://github.com/getsentry/sentry-dart/pull/3940))

### Enhancements

- Migrate the Android plugin to Flutter’s built-in Kotlin support. ([#3961](https://github.com/getsentry/sentry-dart/pull/3961))

### Fixes

- Isolate failures in user-provided callbacks. ([#4026](https://github.com/getsentry/sentry-dart/pull/4026))
- Default event trace context status to `ok` while preserving explicit span statuses. ([#4035](https://github.com/getsentry/sentry-dart/pull/4035))
- Exclude later frame builds from startup timing. ([8ee2d41](https://github.com/getsentry/sentry-dart/commit/8ee2d41ed))
- Align HTTP client error type and value. ([#3934](https://github.com/getsentry/sentry-dart/pull/3934))

### Dependencies

- Update Sentry Cocoa to **9.27.0**. ([#4006](https://github.com/getsentry/sentry-dart/pull/4006))
- Update Sentry JavaScript to **11.0.0**, preserving the default web privacy settings and aligning unhandled session reporting. ([#4032](https://github.com/getsentry/sentry-dart/pull/4032))
- Use `jni >=1.0.0 <1.1.0` and `jnigen 0.17.0`. ([#3931](https://github.com/getsentry/sentry-dart/pull/3931))
## 10.0.0-rc.2

### Breaking Changes

- Default `traceLifecycle` to `SentryTraceLifecycle.stream`, sending spans as they finish instead of as transactions. Errors, messages, and feedback captured inside an active streaming span now link to it. Set `options.traceLifecycle = SentryTraceLifecycle.static` to keep the previous transaction-based behavior. ([#4057](https://github.com/getsentry/sentry-dart/pull/4057))
## 10.0.0-rc.1

### Breaking Changes

- Raise the minimum Android SDK version for Flutter from API 21 to API 26. Set your app's Android `minSdk` to 26 or higher. ([#4049](https://github.com/getsentry/sentry-dart/pull/4049))

### Fixes

- Default event trace context status to `ok` while preserving explicit span statuses. ([#4035](https://github.com/getsentry/sentry-dart/pull/4035))
- Restore Android replay configuration across recorder restarts and prevent overlapping capture schedulers. ([#4037](https://github.com/getsentry/sentry-dart/pull/4037))
## 10.0.0-rc.0

### Breaking Changes

- Require Dart 3.12.0 or newer and Flutter 3.44.0 or newer. ([#3784](https://github.com/getsentry/sentry-dart/pull/3784))
- Remove CocoaPods support. Flutter apps targeting Apple platforms must use Swift Package Manager. ([#3879](https://github.com/getsentry/sentry-dart/pull/3879))
- Remove `enableLogs` and `enableMetrics`. Logs and metrics are always enabled. The logging integration forwards Sentry logs by default; adjust `minSentryLogLevel` or set it to `Level.OFF` to disable forwarding. ([#3983](https://github.com/getsentry/sentry-dart/pull/3983))
- Remove `enableStandaloneAppStartTracing`. When tracing is enabled, app start is always reported as a standalone `app.start` root on Android and iOS. ([#3981](https://github.com/getsentry/sentry-dart/pull/3981))
- Make native failed-request capture opt-in. ([#3885](https://github.com/getsentry/sentry-dart/pull/3885))
- Run error sampling after event processors and `beforeSend`. These callbacks now also run for events that are subsequently sampled out. ([#3955](https://github.com/getsentry/sentry-dart/pull/3955))
- Require `traceId` on `SentryLog`, make logger methods return `void`, and remove `SentryLogAttribute`. ([#3842](https://github.com/getsentry/sentry-dart/pull/3842), [#3852](https://github.com/getsentry/sentry-dart/pull/3852), [#3843](https://github.com/getsentry/sentry-dart/pull/3843))
- Add a `Hint` parameter to the before-send callbacks for logs, metrics, and spans. ([#3847](https://github.com/getsentry/sentry-dart/pull/3847))
- Make feature flags hub/scope-based. ([#3848](https://github.com/getsentry/sentry-dart/pull/3848))
- Remove SDK profiling and deprecated performance collectors. ([#3891](https://github.com/getsentry/sentry-dart/pull/3891), [#3850](https://github.com/getsentry/sentry-dart/pull/3850))
- Remove deprecated `copyWith` APIs and protocol clones, and make `clone()` internal. ([#3877](https://github.com/getsentry/sentry-dart/pull/3877), [#3845](https://github.com/getsentry/sentry-dart/pull/3845))
- Remove the deprecated `SentryFeedbackWidget`. ([#3844](https://github.com/getsentry/sentry-dart/pull/3844))
- Replace `options.log` with internal logging and make `BindingWrapper` and `bindingUtils` internal. ([#3932](https://github.com/getsentry/sentry-dart/pull/3932), [#3940](https://github.com/getsentry/sentry-dart/pull/3940))
- Align span attributes with Sentry Conventions and remove `file.async` from file instrumentation. ([#3805](https://github.com/getsentry/sentry-dart/pull/3805), [#3841](https://github.com/getsentry/sentry-dart/pull/3841))
- Use Breakpad as the default native crash backend on Windows and Linux. ([#4045](https://github.com/getsentry/sentry-dart/pull/4045))

### Features

- Add manual Session Replay controls on Android and iOS through `SentryFlutter.replay`: `start`, `startBuffering`, `pause`, `resume`, `stop`, and `flush`. Explicitly started replays work even when both automatic sample rates are `0`. ([#4010](https://github.com/getsentry/sentry-dart/pull/4010))
- Add app-start extension APIs and lifecycle-specific span getters, and improve startup frame spans. ([#3896](https://github.com/getsentry/sentry-dart/pull/3896), [#3918](https://github.com/getsentry/sentry-dart/pull/3918), [#4018](https://github.com/getsentry/sentry-dart/pull/4018))
- Include sampled-out errors in release health, and report unhandled Flutter errors as unhandled sessions rather than crashes. ([#4008](https://github.com/getsentry/sentry-dart/pull/4008), [#4007](https://github.com/getsentry/sentry-dart/pull/4007))
- Mask `SensitiveContent` by default in Session Replay. ([#3973](https://github.com/getsentry/sentry-dart/pull/3973))
- Record Android replay segment names and span segment-name sources. ([#3897](https://github.com/getsentry/sentry-dart/pull/3897), [#3904](https://github.com/getsentry/sentry-dart/pull/3904))
- Support array attributes in telemetry and attach feature flags to the hub span. ([#3778](https://github.com/getsentry/sentry-dart/pull/3778), [#3806](https://github.com/getsentry/sentry-dart/pull/3806))
- Graduate span streaming and other mature v10 APIs from experimental status. ([#3756](https://github.com/getsentry/sentry-dart/pull/3756), [#3940](https://github.com/getsentry/sentry-dart/pull/3940))

### Enhancements

- Improve Android scope synchronization and replay screenshot transfer performance. ([#3924](https://github.com/getsentry/sentry-dart/pull/3924))
- Support 64-bit integer values from Sentry Native. ([#3760](https://github.com/getsentry/sentry-dart/pull/3760))
- Migrate the Android plugin to Flutter’s built-in Kotlin support. ([#3961](https://github.com/getsentry/sentry-dart/pull/3961))

### Fixes

- Isolate failures in user-provided callbacks. ([#4026](https://github.com/getsentry/sentry-dart/pull/4026))
- Close background JNI workers when their owning isolate exits while preserving native reporting across cached-engine view detachment and reattachment. ([#3987](https://github.com/getsentry/sentry-dart/pull/3987))
- Await in-flight replay captures during scheduler shutdown and skip new captures while the app is not resumed. ([#3935](https://github.com/getsentry/sentry-dart/pull/3935))
- Prevent delayed-frame state errors and guard script completion. ([#3876](https://github.com/getsentry/sentry-dart/pull/3876), [#3912](https://github.com/getsentry/sentry-dart/pull/3912))
- Add the app-start screen attribute and exclude later frame builds from startup timing. ([#3893](https://github.com/getsentry/sentry-dart/pull/3893), [8ee2d41](https://github.com/getsentry/sentry-dart/commit/8ee2d41ed))
- Align HTTP client error type and value. ([#3934](https://github.com/getsentry/sentry-dart/pull/3934))
- Accept double timestamps in Android network breadcrumbs. ([#3859](https://github.com/getsentry/sentry-dart/pull/3859))
- Read normalized rate-limit headers and report missing metric byte outcomes. ([#3883](https://github.com/getsentry/sentry-dart/pull/3883), [#3905](https://github.com/getsentry/sentry-dart/pull/3905))

### Dependencies

- Update Sentry Android to **8.56.0**. ([#4015](https://github.com/getsentry/sentry-dart/pull/4015))
- Update Sentry Cocoa to **9.27.0**. ([#4006](https://github.com/getsentry/sentry-dart/pull/4006))
- Update Sentry Native to **0.16.6**. ([#4013](https://github.com/getsentry/sentry-dart/pull/4013))
- Update Sentry JavaScript to **11.0.0**, preserving the default web privacy settings and aligning unhandled session reporting. ([#4032](https://github.com/getsentry/sentry-dart/pull/4032))
- Use `jni >=1.0.0 <1.1.0` and `jnigen 0.17.0`. ([#3931](https://github.com/getsentry/sentry-dart/pull/3931))
## 10.0.0-beta.0

### Features

- (flutter) Default desktop to Breakpad by @buenaflor in [#4045](https://github.com/getsentry/sentry-dart/pull/4045)

### Dependencies

- (flutter) Bump JS to 11.0.0 by @buenaflor in [#4032](https://github.com/getsentry/sentry-dart/pull/4032)
## 10.0.0-alpha.7

### Features

- (flutter) Revamp app-start frame spans by @buenaflor in [#4018](https://github.com/getsentry/sentry-dart/pull/4018)

### Fixes

- Isolate user callback failures by @sentry-junior in [#4026](https://github.com/getsentry/sentry-dart/pull/4026)
## 10.0.0-alpha.6

### Features

#### Flutter

- Add manual Session Replay controls on Android and iOS through `SentryFlutter.replay`: `start`, `startBuffering`, `pause`, `resume`, `stop`, and `flush`. Explicitly started replays work even when both automatic sample rates are `0`. by @buenaflor in [#4010](https://github.com/getsentry/sentry-dart/pull/4010)

### Fixes

#### Flutter

- Close background JNI workers when their owning isolate exits, while preserving native reporting across cached-engine view detachment and reattachment. by @lucas-zimerman in [#3987](https://github.com/getsentry/sentry-dart/pull/3987)
- Await in-flight replay captures during scheduler shutdown and skip new captures while the app is not resumed. by @lucas-zimerman in [#3935](https://github.com/getsentry/sentry-dart/pull/3935)

### Dependencies

#### Flutter

- Update Sentry Android from 8.55.0 to 8.56.0 by @buenaflor in [#4015](https://github.com/getsentry/sentry-dart/pull/4015)
- Update Sentry Native from 0.16.4 to 0.16.6 by @github-actions in [#3998](https://github.com/getsentry/sentry-dart/pull/3998) and [#4013](https://github.com/getsentry/sentry-dart/pull/4013)

### Internal Changes

- Collect Apple framework symbols by @sentry-junior in [#4003](https://github.com/getsentry/sentry-dart/pull/4003)
## 10.0.0-alpha.5

### Features

#### Flutter

- Unsampled errors affect release health by @buenaflor in [#4008](https://github.com/getsentry/sentry-dart/pull/4008)
- Unhandled Flutter errors do not mark sessions as crashed but unhandled instead by @buenaflor in [#4007](https://github.com/getsentry/sentry-dart/pull/4007)

### Internal Changes

- (deps) Bump Android 8.55.0, Cocoa 9.27.0 by @buenaflor in [#4006](https://github.com/getsentry/sentry-dart/pull/4006)
## 10.0.0-alpha.4

### Features

- Remove the `enableLogs` and `enableMetrics` options. Logs and metrics are now always enabled and can no longer be disabled through `SentryOptions`. Remove any `options.enableLogs` / `options.enableMetrics` assignments from your SDK init. If you use the [logging integration](https://docs.sentry.io/platforms/dart/integrations/logging/), it now forwards log records as Sentry logs as soon as it is added — raise `minSentryLogLevel`, or set it to `Level.OFF`, to opt out. by @buenaflor in [#3983](https://github.com/getsentry/sentry-dart/pull/3983)
- `enableStandaloneAppStartTracing` is removed. App start is always a standalone `app.start` root on Android and iOS when tracing is enabled. The legacy ui.load-attached app start path is gone. by @buenaflor in [#3981](https://github.com/getsentry/sentry-dart/pull/3981)
- (replay) Mask SensitiveContent by default by @buenaflor in [#3973](https://github.com/getsentry/sentry-dart/pull/3973)

### Fixes

- Sampling now runs after `beforeSend` instead of before it, so `ignoreErrors`, ignored exception types, event processors and `beforeSend` all take precedence over the `sampleRate` decision. An event dropped by `beforeSend` is now reported as a `before_send` discard rather than a `sample_rate` one, and `beforeSend` now runs for events that are later sampled out. ([#3855](https://github.com/getsentry/sentry-dart/issues/3855)) by @buenaflor in [#3955](https://github.com/getsentry/sentry-dart/pull/3955)
- (http) Align HTTP client error type and value by @buenaflor in [#3934](https://github.com/getsentry/sentry-dart/pull/3934)

### Internal Changes

- Migrate the Android plugin to Flutter's built-in Kotlin. `sentry_flutter` no longer applies the Kotlin Gradle Plugin itself, which silences Flutter 3.44's warning about plugins applying KGP and unblocks apps moving to AGP 9. by @buenaflor in [#3961](https://github.com/getsentry/sentry-dart/pull/3961)
## 10.0.0-alpha.3

### Features

#### Dart

- Align database, HTTP, app-start, and trace-lifecycle span attributes with Sentry Conventions by @buenaflor in [#3805](https://github.com/getsentry/sentry-dart/pull/3805)

#### Flutter

- Add standalone app-start tracing, extension APIs, and lifecycle-specific span getters by @buenaflor in [#3896](https://github.com/getsentry/sentry-dart/pull/3896) and [#3918](https://github.com/getsentry/sentry-dart/pull/3918)
- Make native failed-request capture opt-in by @buenaflor in [#3885](https://github.com/getsentry/sentry-dart/pull/3885)
- Remove CocoaPods support in favor of Swift Package Manager by @buenaflor in [#3879](https://github.com/getsentry/sentry-dart/pull/3879)
- Record Android replay segment names and span segment-name sources by @buenaflor in [#3897](https://github.com/getsentry/sentry-dart/pull/3897) and [#3904](https://github.com/getsentry/sentry-dart/pull/3904)

### Enhancements

- Improve Android scope synchronization and replay screenshot transfer performance by @buenaflor in [#3924](https://github.com/getsentry/sentry-dart/pull/3924)

### Fixes

#### Flutter

- Prevent delayed-frame state errors and guard script completion by @muhammadkamel and @buenaflor in [#3876](https://github.com/getsentry/sentry-dart/pull/3876) and [#3912](https://github.com/getsentry/sentry-dart/pull/3912)
- Add the app-start screen attribute by @buenaflor in [#3893](https://github.com/getsentry/sentry-dart/pull/3893)

#### Other

- Accept double timestamps in Android network breadcrumbs by @aqrc in [#3859](https://github.com/getsentry/sentry-dart/pull/3859)
- Read normalized rate-limit headers by @sentry-junior in [#3883](https://github.com/getsentry/sentry-dart/pull/3883)
- Add missing metric byte outcomes by @buenaflor in [#3905](https://github.com/getsentry/sentry-dart/pull/3905)

### Dependencies

#### Flutter

- Update Android SDK versions through 8.51.0 by @github-actions in [#3895](https://github.com/getsentry/sentry-dart/pull/3895), [#3921](https://github.com/getsentry/sentry-dart/pull/3921), and [#3938](https://github.com/getsentry/sentry-dart/pull/3938)
- Update Native SDK versions through 0.16.1 by @github-actions in [#3862](https://github.com/getsentry/sentry-dart/pull/3862), [#3910](https://github.com/getsentry/sentry-dart/pull/3910), [#3925](https://github.com/getsentry/sentry-dart/pull/3925), and [#3937](https://github.com/getsentry/sentry-dart/pull/3937)
- Relax the JNI constraint and update jnigen to 0.17.0 by @buenaflor in [#3931](https://github.com/getsentry/sentry-dart/pull/3931)

### Internal Changes

- Remove SDK profiling by @buenaflor in [#3891](https://github.com/getsentry/sentry-dart/pull/3891)
- Remove deprecated `copyWith` APIs by @buenaflor in [#3877](https://github.com/getsentry/sentry-dart/pull/3877)
- Replace `options.log` with `internalLogger` by @buenaflor in [#3932](https://github.com/getsentry/sentry-dart/pull/3932)
- Graduate mature v10 APIs and make `BindingWrapper` and `bindingUtils` internal by @buenaflor in [#3940](https://github.com/getsentry/sentry-dart/pull/3940)
- Share Darwin plugin sources by @buenaflor in [#3922](https://github.com/getsentry/sentry-dart/pull/3922)
- Move the gRPC `MockHub` into `_sentry_testing` by @lucas-zimerman in [#3908](https://github.com/getsentry/sentry-dart/pull/3908)
- Pin Flutter development dependencies by @buenaflor in [#3913](https://github.com/getsentry/sentry-dart/pull/3913)
- Add Supabase and gRPC SDKs to Craft by @buenaflor in [#3884](https://github.com/getsentry/sentry-dart/pull/3884)
## 10.0.0-alpha.2

### Features

- (telemetry) Align span attributes with Sentry Conventions by @buenaflor in [#3805](https://github.com/getsentry/sentry-dart/pull/3805)
- Add feature flags to hub span by @denrase in [#3806](https://github.com/getsentry/sentry-dart/pull/3806)
- (logs) Add Hint to beforeSend for logs, metrics, and spans by @buenaflor in [#3847](https://github.com/getsentry/sentry-dart/pull/3847)
- (logs) Enable logs by default by @buenaflor in [#3846](https://github.com/getsentry/sentry-dart/pull/3846)

### Internal Changes

- (logs) Make traceId required on SentryLog by @buenaflor in [#3842](https://github.com/getsentry/sentry-dart/pull/3842)
- Make clone() internal and remove deprecated protocol clones by @buenaflor in [#3845](https://github.com/getsentry/sentry-dart/pull/3845)
- (dart) Make feature flags hub/scope-based by @buenaflor in [#3848](https://github.com/getsentry/sentry-dart/pull/3848)
- (file) Remove file.async attributes from instrumentation by @buenaflor in [#3841](https://github.com/getsentry/sentry-dart/pull/3841)
- (logs) Make logger methods return void by @buenaflor in [#3852](https://github.com/getsentry/sentry-dart/pull/3852)
- (logs) Remove deprecated SentryLogAttribute by @buenaflor in [#3843](https://github.com/getsentry/sentry-dart/pull/3843)
- Remove deprecated performance collectors by @buenaflor in [#3850](https://github.com/getsentry/sentry-dart/pull/3850)
- (feedback) Remove deprecated SentryFeedbackWidget by @buenaflor in [#3844](https://github.com/getsentry/sentry-dart/pull/3844)
## 10.0.0-alpha.1

### Features

#### Dart

- Add array attributes to telemetry by @buenaflor in [#3778](https://github.com/getsentry/sentry-dart/pull/3778)
- Mark span streaming API as non-experimental by @buenaflor in [#3756](https://github.com/getsentry/sentry-dart/pull/3756)

#### Other

- (flutter) Support SwiftPM on Flutter 3.44+ by @buenaflor in [#3784](https://github.com/getsentry/sentry-dart/pull/3784)

### Enhancements

- (flutter) Support int64 values from sentry-native by @buenaflor in [#3760](https://github.com/getsentry/sentry-dart/pull/3760)
## 9.30.1

### Fixes

- (flutter) Restore Android replay config by @buenaflor in [#4037](https://github.com/getsentry/sentry-dart/pull/4037)
## 9.30.0

### Fixes

#### Flutter

- Fix an Android native/GPU memory leak caused by the background JNI worker outliving its Flutter engine, while preserving native reporting across cached-engine view detachment and reattachment. by @lucas-zimerman in [#3987](https://github.com/getsentry/sentry-dart/pull/3987)
- Await in-flight replay capture on scheduler stop by @lucas-zimerman in [#3935](https://github.com/getsentry/sentry-dart/pull/3935)

### Dependencies

#### Deps

- chore(deps): Update Android SDK to v8.56.0 by @buenaflor in [#4015](https://github.com/getsentry/sentry-dart/pull/4015)
- chore(deps): update Native SDK to v0.16.6 by @github-actions in [#4013](https://github.com/getsentry/sentry-dart/pull/4013)

### Internal Changes

- (symbols) Collect Apple framework symbols by @sentry-junior in [#4003](https://github.com/getsentry/sentry-dart/pull/4003)
## 9.29.0

### Dependencies

#### Deps

- chore(deps): Update Android SDK to v8.54.0 by @buenaflor in [#4001](https://github.com/getsentry/sentry-dart/pull/4001)
- chore(deps): update Native SDK to v0.16.5 by @github-actions in [#3998](https://github.com/getsentry/sentry-dart/pull/3998)
## 9.28.0

### Features

- (dart) Add sentry.trace_lifecycle span attribute by @buenaflor in [#3985](https://github.com/getsentry/sentry-dart/pull/3985)
- Copy `app.vitals.start.screen` onto standalone `app.start` children so app start spans can be drilled down by launch screen. by @buenaflor in [#3988](https://github.com/getsentry/sentry-dart/pull/3988)
- `enableLogs` and `enableMetrics` now only control automatic collection. Logs and metrics sent through `Sentry.logger` and `Sentry.metrics` are always captured, regardless of these options. by @buenaflor in [#3982](https://github.com/getsentry/sentry-dart/pull/3982)

### Fixes

#### Dart

- Record client report outcome for dropped spans by @lucas-zimerman in [#3971](https://github.com/getsentry/sentry-dart/pull/3971)
- Read Windows total physical memory via the native `GlobalMemoryStatusEx` API instead of spawning the deprecated `wmic.exe` (or PowerShell) process. by @cf-rhett in [#3894](https://github.com/getsentry/sentry-dart/pull/3894)

#### Flutter

- Narrow Android R8 keep rule from io.sentry.** to bound classes by @lucas-zimerman in [#3972](https://github.com/getsentry/sentry-dart/pull/3972)
- Skip screenshot capture of a zero-sized boundary by @buenaflor in [#3954](https://github.com/getsentry/sentry-dart/pull/3954)
- Support AGP 9's built-in Kotlin by @TheoGermain in [#3970](https://github.com/getsentry/sentry-dart/pull/3970)

### Dependencies

- chore(deps): update Native SDK to v0.16.4 by @github-actions in [#3986](https://github.com/getsentry/sentry-dart/pull/3986)
## 9.27.0

### Features

- Add HTTP request/response header and body capture for Session Replay network breadcrumbs, gated by `networkDetailAllowUrls`/`networkDetailDenyUrls`. by @lucas-zimerman in [#3875](https://github.com/getsentry/sentry-dart/pull/3875)

### Fixes

- (dart) Handle HTTP 413 in HttpTransport by @lucas-zimerman in [#3951](https://github.com/getsentry/sentry-dart/pull/3951)

### Dependencies

#### Deps

- chore(deps): update Android SDK to v8.53.0 by @github-actions in [#3963](https://github.com/getsentry/sentry-dart/pull/3963)
- chore(deps): update Native SDK to v0.16.2 by @github-actions in [#3952](https://github.com/getsentry/sentry-dart/pull/3952)

### Internal Changes

- Replace curl-pipe-bash with action-setup-cli for Sentry CLI setup by @oioki in [#3949](https://github.com/getsentry/sentry-dart/pull/3949)
- Remove secrets: inherit from changelog-preview workflow by @oioki in [#3946](https://github.com/getsentry/sentry-dart/pull/3946)
## 9.26.0

### Features

#### Flutter

- Standalone app start tracing (experimental) by @buenaflor in [#3896](https://github.com/getsentry/sentry-dart/pull/3896) and [#3918](https://github.com/getsentry/sentry-dart/pull/3918)
  - App start is reported as its own `App Start` root (`app.start`) spanning process start to the first frame, instead of being nested under the synthetic initial `ui.load`. This gives startup its own lifecycle and sampling decision.
  - Opt in via `options.enableStandaloneAppStartTracing`. Requires tracing, is supported on Android and iOS, and works with both `SentryTraceLifecycle.static` and `SentryTraceLifecycle.stream`.
  - Extend the app start past the first frame with `SentryFlutter.extendAppStart()` and `SentryFlutter.finishExtendedAppStart()`, so startup work that finishes later — remote config, auth restore, flag hydration — is part of the reported duration.
  - Always finish what you extend. While an extension is open the app start stays open too; if it hits its 30 second deadline first, the extension is dropped and the reported duration falls back to the first frame.

```dart
// Opt in during SDK init and extend the app start across your startup work.
await SentryFlutter.init(
  (options) {
    options.dsn = 'https://example@sentry.io/add-your-dsn-here';
    options.tracesSampleRate = 1.0;
    options.enableStandaloneAppStartTracing = true;
  },
  appRunner: () async {
    // Extend before the first frame renders.
    SentryFlutter.extendAppStart();
    runApp(const MyApp());

    try {
      await remoteConfig.fetchAndActivate();
      await auth.restoreSession();
    } finally {
      // Releases the app start to report, measured up to here.
      await SentryFlutter.finishExtendedAppStart();
    }
  },
);
```

  - To nest your own spans under the extension, take the span itself — `SentryFlutter.getExtendedAppStartSpan()` on the static lifecycle, `SentryFlutter.getExtendedAppStartSpanV2()` on the streaming one. Each returns `null` on the other lifecycle and once the extension has ended. Finishing the span completes the extension, so there is no need to also call `finishExtendedAppStart()`.

```dart
// Static lifecycle.
final appStart = SentryFlutter.getExtendedAppStartSpan();
final child = appStart?.startChild('app.init', description: 'Load config');
try {
  await loadConfig();
} finally {
  await child?.finish();
}

// Streaming lifecycle. Only pass a parent when there is one — passing `null`
// starts a root span instead of a child.
final appStartV2 = SentryFlutter.getExtendedAppStartSpanV2();
if (appStartV2 != null) {
  await Sentry.startSpan(
    'Load config',
    (span) => loadConfig(),
    parentSpan: appStartV2,
  );
} else {
  await loadConfig();
}
```

### Fixes

- Read normalized rate limit headers by @sentry-junior in [#3883](https://github.com/getsentry/sentry-dart/pull/3883)

### Enhancements

- (flutter) Speed up Android scope sync and replay capture by @buenaflor in [#3924](https://github.com/getsentry/sentry-dart/pull/3924)

### Dependencies

#### Deps

- chore(deps): update Android SDK to v8.45.0 by @github-actions in [#3790](https://github.com/getsentry/sentry-dart/pull/3790)
- chore(deps): update Native SDK to v0.15.1 by @github-actions in [#3757](https://github.com/getsentry/sentry-dart/pull/3757)

#### Flutter

- Bump jni to 1.0.0 and jnigen to 0.16.0 in v10 by @buenaflor in [#3765](https://github.com/getsentry/sentry-dart/pull/3765)
- Bump sentry-cocoa to 9.17.1 in v10 by @buenaflor in [#3764](https://github.com/getsentry/sentry-dart/pull/3764)

### Internal Changes

- (flutter) Remove flaky frames measurement tests by @buenaflor in [#3783](https://github.com/getsentry/sentry-dart/pull/3783)
- chore(deps): update Native SDK to v0.16.1 by @github-actions in [#3937](https://github.com/getsentry/sentry-dart/pull/3937)
- chore(deps): update Android SDK to v8.51.0 by @github-actions in [#3938](https://github.com/getsentry/sentry-dart/pull/3938)

### Internal Changes

- (deps) Pin Flutter development dependencies by @buenaflor in [#3913](https://github.com/getsentry/sentry-dart/pull/3913)
- (grpc) Move MockHub to \_sentry_testing package by @lucas-zimerman in [#3908](https://github.com/getsentry/sentry-dart/pull/3908)
## 9.25.0

### Features

- (replay) Record segment names on Android by @buenaflor in [#3897](https://github.com/getsentry/sentry-dart/pull/3897)
- (tracing) Emit segment name source by @buenaflor in [#3904](https://github.com/getsentry/sentry-dart/pull/3904)

### Fixes

#### Flutter

- Guard script completion by @buenaflor in [#3912](https://github.com/getsentry/sentry-dart/pull/3912)
- Add app start screen attribute by @buenaflor in [#3893](https://github.com/getsentry/sentry-dart/pull/3893)
- Prevent StateError when delayed frames list is empty by @muhammadkamel in [#3876](https://github.com/getsentry/sentry-dart/pull/3876)

#### Other

- (metrics) Add missing metric byte outcomes by @buenaflor in [#3905](https://github.com/getsentry/sentry-dart/pull/3905)

### Dependencies

#### Deps

- chore(deps): update Native SDK to v0.15.4 by @github-actions in [#3910](https://github.com/getsentry/sentry-dart/pull/3910)
- chore(deps): update Android SDK to v8.49.0 by @github-actions in [#3895](https://github.com/getsentry/sentry-dart/pull/3895)
- chore(deps): update Cocoa SDK to v8.58.4 by @github-actions in [#3864](https://github.com/getsentry/sentry-dart/pull/3864)

### Internal Changes

- (dart) Accept beta wasm function name by @sentry-junior in [#3898](https://github.com/getsentry/sentry-dart/pull/3898)
## 9.24.0

### Features

- Add feature flags to hub span by @denrase in [#3806](https://github.com/getsentry/sentry-dart/pull/3806)

### Fixes

- (replay) Accept Double timestamps in Android network breadcrumb conversion by @aqrc in [#3859](https://github.com/getsentry/sentry-dart/pull/3859)
## 9.23.0

### Features

#### Dart

- Add array attributes to telemetry by @buenaflor in [#3778](https://github.com/getsentry/sentry-dart/pull/3778)
- Mark span streaming API as non-experimental by @buenaflor in [#3756](https://github.com/getsentry/sentry-dart/pull/3756)

#### Other

- (flutter) Support SwiftPM on Flutter 3.44+ by @buenaflor in [#3784](https://github.com/getsentry/sentry-dart/pull/3784)
- (grpc) Add integration support for GRPC by @lucas-zimerman in [#3721](https://github.com/getsentry/sentry-dart/pull/3721)
- (tracing) Simplify span v2 status to ok/error by @buenaflor in [#3840](https://github.com/getsentry/sentry-dart/pull/3840)
- Report blocked_main_thread on streaming spans by @buenaflor in [#3821](https://github.com/getsentry/sentry-dart/pull/3821)

### Fixes

- (rate-limiting) Honor span and feedback rate limits by @buenaflor in [#3809](https://github.com/getsentry/sentry-dart/pull/3809)
- Correct feature flag scope buffer updates by @denrase in [#3797](https://github.com/getsentry/sentry-dart/pull/3797)

### Enhancements

- (flutter) Support int64 values from sentry-native by @buenaflor in [#3760](https://github.com/getsentry/sentry-dart/pull/3760)

### Dependencies

#### Deps

- chore(deps): update Android SDK to v8.45.0 by @github-actions in [#3790](https://github.com/getsentry/sentry-dart/pull/3790)
- chore(deps): update Native SDK to v0.15.1 by @github-actions in [#3757](https://github.com/getsentry/sentry-dart/pull/3757)

#### Flutter

- Bump jni to 1.0.0 and jnigen to 0.16.0 in v10 by @buenaflor in [#3765](https://github.com/getsentry/sentry-dart/pull/3765)
- Bump sentry-cocoa to 9.17.1 in v10 by @buenaflor in [#3764](https://github.com/getsentry/sentry-dart/pull/3764)
- chore(deps): update Android SDK to v8.47.0 by @github-actions in [#3849](https://github.com/getsentry/sentry-dart/pull/3849)
- chore(deps): update Native SDK to v0.15.2 by @github-actions in [#3785](https://github.com/getsentry/sentry-dart/pull/3785)

### Internal Changes

- (flutter) Remove flaky frames measurement tests by @buenaflor in [#3783](https://github.com/getsentry/sentry-dart/pull/3783)
- (skills) Expand test-guidelines and drop stale deps by @buenaflor in [#3807](https://github.com/getsentry/sentry-dart/pull/3807)
- Add PR template checkbox for cross sdk review on public API changes by @antonis in [#3822](https://github.com/getsentry/sentry-dart/pull/3822)
- Block manual CHANGELOG.md edits by @buenaflor in [#3810](https://github.com/getsentry/sentry-dart/pull/3810)
- Fix Dependabot pub paths and pin GitHub Action by @buenaflor in [#3804](https://github.com/getsentry/sentry-dart/pull/3804)
- Add AI Use section to CONTRIBUTING.md by @christophaigner in [#3803](https://github.com/getsentry/sentry-dart/pull/3803)
## 9.22.0

### Features

- (flutter) Add replay trace ID sync for Android by @buenaflor in [#3744](https://github.com/getsentry/sentry-dart/pull/3744)

### Fixes

- (dart) Add missing log byte outcomes by @buenaflor in [#3745](https://github.com/getsentry/sentry-dart/pull/3745)
- (flutter) Add replay IDs to span telemetry by @buenaflor in [#3739](https://github.com/getsentry/sentry-dart/pull/3739)

### Enhancements

- (dart) Add span v2 envelope `ingest_settings` metadata by @buenaflor in [#3700](https://github.com/getsentry/sentry-dart/pull/3700)

### Dependencies

#### Deps

- chore(deps): update Android SDK to v8.43.2 by @github-actions in [#3755](https://github.com/getsentry/sentry-dart/pull/3755)
- chore(deps): update Native SDK to v0.14.2 by @github-actions in [#3683](https://github.com/getsentry/sentry-dart/pull/3683)
## 9.21.0

### Features

- Rename `SentryFeedbackWidget` to `SentryFeedbackForm` by @denrase in [#3702](https://github.com/getsentry/sentry-dart/pull/3702)
  - `SentryFeedbackWidget` is deprecated and will be removed in the next major version. Use `SentryFeedbackForm` instead.

### Fixes

#### Dart

- Make sentryOnError synchronous in runZonedGuarded by @theprantadutta in [#3697](https://github.com/getsentry/sentry-dart/pull/3697)
- Route SDK diagnostic logs to browser console on web by @theprantadutta in [#3698](https://github.com/getsentry/sentry-dart/pull/3698)

#### Flutter

- Forward sample rate to native SDKs by @buenaflor in [#3722](https://github.com/getsentry/sentry-dart/pull/3722)
- Release Android JNI refs by @buenaflor in [#3712](https://github.com/getsentry/sentry-dart/pull/3712)
- Release replay JNI refs by @buenaflor in [#3699](https://github.com/getsentry/sentry-dart/pull/3699)

### Enhancements

#### Flutter

- Move Android JNI work to core worker to avoid work on main isolate by @buenaflor in [#3713](https://github.com/getsentry/sentry-dart/pull/3713)
- Optimize Android scope sync by @buenaflor in [#3708](https://github.com/getsentry/sentry-dart/pull/3708)

### Dependencies

#### Deps

- chore(deps): update Cocoa SDK to v8.58.3 by @github-actions in [#3726](https://github.com/getsentry/sentry-dart/pull/3726)
- chore(deps): update Android SDK to v8.43.0 by @github-actions in [#3727](https://github.com/getsentry/sentry-dart/pull/3727)

### Internal Changes

- (flutter) Align CI with stable SwiftPM defaults by @buenaflor in [#3710](https://github.com/getsentry/sentry-dart/pull/3710)
## 9.20.0

### Features

- (span-first) Add transaction and app start type span attributes by @buenaflor in [#3678](https://github.com/getsentry/sentry-dart/pull/3678)
- Prevent cross-organization trace continuation by @antonis in [#3567](https://github.com/getsentry/sentry-dart/pull/3567)
  - By default, the SDK now extracts the organization ID from the DSN (e.g. `o123.ingest.sentry.io`) and compares it with the `sentry-org_id` value in incoming baggage headers. When the two differ, the SDK starts a fresh trace instead of continuing the foreign one. This guards against accidentally linking traces across organizations.
  - New option `strictTraceContinuation` (default `false`): when enabled, both the SDK's org ID **and** the incoming baggage org ID must be present and match for a trace to be continued. Traces with a missing org ID on either side are rejected.
  - New option `orgId`: allows explicitly setting the organization ID for self-hosted and Relay setups where it cannot be extracted from the DSN.
  - Options are also applied to the native Android SDK. On iOS, only the Dart layer enforces strict trace continuation.

### Fixes

#### Flutter

- Avoid JNI callbacks for Android scope sync by @denrase in [#3676](https://github.com/getsentry/sentry-dart/pull/3676)
- Send frame delay in seconds by @buenaflor in [#3677](https://github.com/getsentry/sentry-dart/pull/3677)

### Dependencies

#### Deps

- chore(deps): update Android SDK to v8.41.0 by @github-actions in [#3687](https://github.com/getsentry/sentry-dart/pull/3687)
- chore(deps): update Cocoa SDK to v8.58.2 by @github-actions in [#3664](https://github.com/getsentry/sentry-dart/pull/3664)
- chore(deps): update Native SDK to v0.13.8 by @github-actions in [#3667](https://github.com/getsentry/sentry-dart/pull/3667)

### Internal Changes

- Remove collection runtime dependency by @buenaflor in [#3680](https://github.com/getsentry/sentry-dart/pull/3680)
- Notify linked issues on release by @buenaflor in [#3685](https://github.com/getsentry/sentry-dart/pull/3685)
- Enforce conventional commit format for PR titles by @buenaflor in [#3666](https://github.com/getsentry/sentry-dart/pull/3666)
## 9.19.0

### Features

- Span-first trace lifecycle (experimental) by @buenaflor in [#3659](https://github.com/getsentry/sentry-dart/pull/3659)
  - Streams spans to Sentry as each one finishes instead of buffering them into a transaction envelope at the root.
  - Opt in via `options.traceLifecycle`. The classic transaction-based `SentryTraceLifecycle.static` remains the default.
  - In stream mode, create spans with the new `Sentry.startSpan` / `Sentry.startSpanSync` APIs — the transaction APIs (`Sentry.startTransaction`, `ISentrySpan.startChild`) do nothing in this mode.
  - Auto-instrumentations (frames, app start, TTID/TTFD, navigation, user interaction, HTTP, databases, GraphQL link) automatically switch to the streaming API when enabled.

```dart
// Opt in during SDK init.
await SentryFlutter.init((options) {
  options.dsn = 'https://example@sentry.io/add-your-dsn-here';
  options.tracesSampleRate = 1.0;
  options.traceLifecycle = SentryTraceLifecycle.stream;
});

// Async work — the span ends and is sent when the future completes.
final order = await Sentry.startSpan('checkout', (span) async {
  span.setAttribute('cart.item_count', SentryAttribute.int(cart.items.length));

  // Automatically parents to 'checkout' via zones.
  final payment = await Sentry.startSpan('process-payment', (span) {
    return paymentService.charge(cart.total);
  });

  return orderService.create(cart, payment: payment);
});

// Sync variant.
final total = Sentry.startSpanSync('calculate-total', (span) {
  return cart.items.fold<double>(0, (sum, item) => sum + item.price);
});
```

### Fixes

- (feedback) Show success message after feedback submission by @denrase in [#3609](https://github.com/getsentry/sentry-dart/pull/3609)

### Enhancements

- (navigator-observer) `enableNewTraceOnNavigation` is now opt-in by @buenaflor in [#3657](https://github.com/getsentry/sentry-dart/pull/3657)
  - `SentryNavigatorObserver` no longer generates a fresh trace id on every push/pop/replace by default. One trace per session (the previous opt-in behavior) is now the default and preserves trace continuity across navigations.
  - If you relied on the old behavior, opt back in explicitly:

```dart
SentryNavigatorObserver(
  enableNewTraceOnNavigation: true,
);
```

### Dependencies

- chore(deps): update Android SDK to v8.39.1 by @github-actions in [#3646](https://github.com/getsentry/sentry-dart/pull/3646)

### Internal Changes

#### Deps

- Bump actions/create-github-app-token from 3.0.0 to 3.1.1 by @dependabot in [#3652](https://github.com/getsentry/sentry-dart/pull/3652)
- Bump getsentry/craft/.github/workflows/changelog-preview.yml from 2.25.2 to 2.25.4 by @dependabot in [#3655](https://github.com/getsentry/sentry-dart/pull/3655)
- Bump actions/cache from 5.0.4 to 5.0.5 by @dependabot in [#3656](https://github.com/getsentry/sentry-dart/pull/3656)

#### Other

- Integrate Warden for AI-powered PR code review by @buenaflor in [#3651](https://github.com/getsentry/sentry-dart/pull/3651)
## 9.18.0

### Dependencies

- chore(deps): update Native SDK to v0.13.7 by @github-actions in [#3645](https://github.com/getsentry/sentry-dart/pull/3645)

### Internal Changes

- (flutter-example) Fix macOS SPM build and bump AGP to 8.6.0 by @buenaflor in [#3644](https://github.com/getsentry/sentry-dart/pull/3644)
- (supabase) Fix flaky error client test for postgrest retry by @buenaflor in [#3643](https://github.com/getsentry/sentry-dart/pull/3643)
- Add SDK features for beforeSend callbacks by @buenaflor in [#3608](https://github.com/getsentry/sentry-dart/pull/3608)
- Add dep update pattern to Dependencies changelog category by @buenaflor in [#3642](https://github.com/getsentry/sentry-dart/pull/3642)
- Replace Danger with release.yml changelog policy by @buenaflor in [#3641](https://github.com/getsentry/sentry-dart/pull/3641)
## 9.17.0

### Fixes

- Revert fetching `sentry-native` from release zip, use git source instead to fix permission issues ([#3630](https://github.com/getsentry/sentry-dart/issues/3630))

### Dependencies

- Bump Native SDK from v0.13.3 to v0.13.6 ([#3606](https://github.com/getsentry/sentry-dart/pull/3606))
  - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#0136)
  - [diff](https://github.com/getsentry/sentry-native/compare/0.13.3...0.13.6)
- Bump Cocoa SDK from v8.58.0 to v8.58.1 ([#3632](https://github.com/getsentry/sentry-dart/pull/3632))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8581)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.58.0...8.58.1)
- Bump Android SDK from v8.37.1 to v8.38.0 ([#3631](https://github.com/getsentry/sentry-dart/pull/3631))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#8380)
  - [diff](https://github.com/getsentry/sentry-java/compare/8.37.1...8.38.0)
## 9.16.1

- Experimental span-streaming API with `startSpan`
### Fixes

- Sentry Native not building due to failing `git clone` ([#3621](https://github.com/getsentry/sentry-dart/pull/3621))
## 9.16.0

### Dependencies

- Bump Android SDK from v8.36.0 to v8.37.1 ([#3588](https://github.com/getsentry/sentry-dart/pull/3588), [#3595](https://github.com/getsentry/sentry-dart/pull/3595))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#8371)
  - [diff](https://github.com/getsentry/sentry-java/compare/8.36.0...8.37.1)
- Bump Native SDK from v0.13.2 to v0.13.3 ([#3577](https://github.com/getsentry/sentry-dart/pull/3577))
  - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#0133)
  - [diff](https://github.com/getsentry/sentry-native/compare/0.13.2...0.13.3)
## 9.15.0

### Fixes

- Stop re-triggering hitTest in SentryUserInteractionWidget on pointerUp ([#3540](https://github.com/getsentry/sentry-dart/pull/3540))
- Use seconds since the Unix epoch for `log.timestamp` ([#3558](https://github.com/getsentry/sentry-dart/pull/3558))
- Implement `SqfliteDatabaseExecutor` to prevent `TypeError` on `getVersion/setVersion` ([3539](https://github.com/getsentry/sentry-dart/pull/3539))

### Dependencies

- Bump Android SDK from v8.33.0 to v8.36.0 ([#3546](https://github.com/getsentry/sentry-dart/pull/3546), [#3569](https://github.com/getsentry/sentry-dart/pull/3569))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#8360)
  - [diff](https://github.com/getsentry/sentry-java/compare/8.33.0...8.36.0)
- Bump Native SDK from v0.12.8 to v0.13.2 ([#3535](https://github.com/getsentry/sentry-dart/pull/3535))
  - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#0132)
  - [diff](https://github.com/getsentry/sentry-native/compare/0.12.8...0.13.2)
- Bump Cocoa SDK from v8.56.2 to v8.58.0 ([#3475](https://github.com/getsentry/sentry-dart/pull/3475))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8580)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.56.2...8.58.0)
## 9.14.0

### Features

- Add `enableTombstone` option for improved native crash reporting on Android 12+ ([#3526](https://github.com/getsentry/sentry-dart/pull/3526))
  - When enabled, uses Android's `ApplicationExitInfo.REASON_CRASH_NATIVE` to capture native crashes with more detailed thread information
  - Disabled by default

### Fixes

- Dont guard user attributes behind `sendDefaultPii` for logs and metrics ([#3524](https://github.com/getsentry/sentry-dart/pull/3524))

### Dependencies

- Bump Native SDK from v0.12.6 to v0.12.8 ([#3514](https://github.com/getsentry/sentry-dart/pull/3514), [#3520](https://github.com/getsentry/sentry-dart/pull/3520))
  - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#0128)
  - [diff](https://github.com/getsentry/sentry-native/compare/0.12.6...0.12.8)
- Bump Android SDK from v8.32.0 to v8.33.0 ([#3529](https://github.com/getsentry/sentry-dart/pull/3529))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#8330)
  - [diff](https://github.com/getsentry/sentry-java/compare/8.32.0...8.33.0)

<summary><b>Internal Changes</b></summary>

- Add `sentry.javascript.browser.flutter` sdk name for native js errors ([#3525](https://github.com/getsentry/sentry-dart/pull/3525))

</details>
## 9.13.0

### Features

- Synchronize `traceId` to native SDKs ([#3507](https://github.com/getsentry/sentry-dart/pull/3507))
  - Native events (e.g. from Android or iOS) such as errors, logs, and spans now share the same trace as Dart events, enabling unified trace views across layers

### Dependencies

- Bump Android SDK from v8.31.0 to v8.32.0 ([#3506](https://github.com/getsentry/sentry-dart/pull/3506))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#8320)
  - [diff](https://github.com/getsentry/sentry-java/compare/8.31.0...8.32.0)
- Bump JavaScript SDK from v10.6.0 to v10.38.0 ([#3474](https://github.com/getsentry/sentry-dart/pull/3474))
  - [changelog](https://github.com/getsentry/sentry-javascript/blob/develop/CHANGELOG.md#10380)
  - [diff](https://github.com/getsentry/sentry-javascript/compare/10.6.0...10.38.0)
- Bump Native SDK from v0.12.5 to v0.12.6 ([#3502](https://github.com/getsentry/sentry-dart/pull/3502))
  - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#0126)
  - [diff](https://github.com/getsentry/sentry-native/compare/0.12.5...0.12.6)

<details>
<summary><b>Internal Changes</b></summary>

- Add SDK features metadata for SPM vs CocoaPods tracking ([#3508](https://github.com/getsentry/sentry-dart/pull/3508))

</details>
## 9.12.0

### Dependencies

- Bump Native SDK from v0.12.3 to v0.12.5 ([#3481](https://github.com/getsentry/sentry-dart/pull/3481))
  - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#0125)
  - [diff](https://github.com/getsentry/sentry-native/compare/0.12.3...0.12.5)
- Bump Android SDK from v8.30.0 to v8.31.0 ([#3476](https://github.com/getsentry/sentry-dart/pull/3476))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#8310)
  - [diff](https://github.com/getsentry/sentry-java/compare/8.30.0...8.31.0)
## 9.11.0

### Features

- Trace connected metrics ([#3450](https://github.com/getsentry/sentry-dart/pull/3450))
  - This feature is enabled by default.
  - To send metrics use the following APIs:
    - `Sentry.metrics.gauge(...)`
    - `Sentry.metrics.count(...)`
    - `Sentry.metrics.distribution(...)`
  - For more details read the [Flutter metrics documentation](https://docs.sentry.io/platforms/dart/guides/flutter/metrics/).
- Add `captureNativeFailedRequests` option for iOS/macOS ([#3472](https://github.com/getsentry/sentry-dart/pull/3472))
  - This option allows controlling native HTTP error capturing independently from `captureFailedRequests`.
  - When `null` (the default), it falls back to `captureFailedRequests` for backwards compatibility.
  - Set to `false` to disable native failed request capturing while keeping Dart-side capturing enabled.

### Fixes

- Catch client exceptions in HttpTransport.send ([#3490](https://github.com/getsentry/sentry-dart/pull/3490))

### Dependencies

- Bump Android SDK from v8.28.0 to v8.30.0 ([#3451](https://github.com/getsentry/sentry-dart/pull/3451))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#8300)
  - [diff](https://github.com/getsentry/sentry-java/compare/8.28.0...8.30.0)

<details>
<summary><b>Internal Changes</b></summary>

- Refactor Logging API to be consistent with Metrics ([#3463](https://github.com/getsentry/sentry-dart/pull/3463))
- Remove deprecated `beforeMetricCallback` from options ([#3484](https://github.com/getsentry/sentry-dart/pull/3450))
- Add span factory to allow swappable span backends in integrations ([#3488](https://github.com/getsentry/sentry-dart/pull/3450))

</details>
## 9.11.0-beta.2

### Fixes

- Catch client exceptions in HttpTransport.send ([#3490](https://github.com/getsentry/sentry-dart/pull/3490))

### Internals

- Remove deprecated `beforeMetricCallback` from options ([#3484](https://github.com/getsentry/sentry-dart/pull/3450))
- Add span factory to allow swappable span backends in integrations ([#3488](https://github.com/getsentry/sentry-dart/pull/3450))
## 9.11.0-beta.1

### Features

- Trace connected metrics ([#3450](https://github.com/getsentry/sentry-dart/pull/3450))
  - This feature is enabled by default.
  - To send metrics use the following APIs:
    - `Sentry.metrics.gauge(...)`
    - `Sentry.metrics.count(...)`
    - `Sentry.metrics.distribution(...)`
- Add `captureNativeFailedRequests` option for iOS/macOS ([#3472](https://github.com/getsentry/sentry-dart/pull/3472))
  - This option allows controlling native HTTP error capturing independently from `captureFailedRequests`.
  - When `null` (the default), it falls back to `captureFailedRequests` for backwards compatibility.
  - Set to `false` to disable native failed request capturing while keeping Dart-side capturing enabled.

### Enhancements

- Refactor Logging API to be consistent with Metrics ([#3463](https://github.com/getsentry/sentry-dart/pull/3463))

### Dependencies

- Bump Android SDK from v8.28.0 to v8.30.0 ([#3451](https://github.com/getsentry/sentry-dart/pull/3451))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#8300)
  - [diff](https://github.com/getsentry/sentry-java/compare/8.28.0...8.30.0)
## 9.10.0

### Fixes

- Kotlin language version handling in Android ([#3436](https://github.com/getsentry/sentry-dart/pull/3436))

### Enhancements

- Replace log batcher with telemetry processor ([#3448](https://github.com/getsentry/sentry-dart/pull/3448))

### Dependencies

- Bump Native SDK from v0.10.0 to v0.12.3 ([#3438](https://github.com/getsentry/sentry-dart/pull/3438))
  - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#0123)
  - [diff](https://github.com/getsentry/sentry-native/compare/0.10.0...0.12.3)
## 9.9.2

### Fixes

- Android not sending events when `autoInitializedNativeSdk` is disabled ([#3420](https://github.com/getsentry/sentry-dart/pull/3420))
## 9.9.1

### Fixes

- Cold/warm start spans not attaching if TTFD takes more than 3 seconds to report ([#3404](https://github.com/getsentry/sentry-dart/pull/3404))
- Ensure that the JNI `ScopesAdapter` instance is released after use ([#3411](https://github.com/getsentry/sentry-dart/pull/3411))
## 9.9.0

### Features

- Add `Sentry.setAttributes` and `Sentry.removeAttribute` ([#3352](https://github.com/getsentry/sentry-dart/pull/3352))
    - These attributes are set at the scope level and apply to all logs (and later to metrics and spans).
    - When a scope attribute conflicts with a log-level attribute, the log-level attribute always takes precedence.
- Sentry Supabase Integration ([#2913](https://github.com/getsentry/sentry-dart/pull/2913))
    - Adds the `sentry_supabase` package to instrument supabase with Sentry breadcrumbs, traces and errors.

### Fixes

- Added `consumerProguardFiles 'proguard-rules.pro'` to the debug build configuration to ensure ProGuard rules are consistently applied across both release and debug variants. ([#3339](https://github.com/getsentry/sentry-dart/pull/3339))
- Dart to native type conversion ([#3372](https://github.com/getsentry/sentry-dart/pull/3372))
- Revert FFI usage on iOS/macOS due to symbol stripping issues ([#3379](https://github.com/getsentry/sentry-dart/pull/3379))
- Android app crashing on hot-restart in debug mode ([#3358](https://github.com/getsentry/sentry-dart/pull/3358))
- Dont use `Companion` in JNI calls and properly release JNI refs ([#3354](https://github.com/getsentry/sentry-dart/pull/3354))
    - This potentially fixes segfault crashes related to JNI

### Enhancements

- Refactor `captureReplay` and `setReplayConfig` to use JNI ([#3318](https://github.com/getsentry/sentry-dart/pull/3318))
- Refactor `init` to use JNI ([#3324](https://github.com/getsentry/sentry-dart/pull/3324))
- Flush logs if client/hub/sdk is closed ([#3335](https://github.com/getsentry/sentry-dart/pull/3335)

### Dependencies 

- Bump Android SDK from v8.21.1 to v8.28.0 ([#3391](https://github.com/getsentry/sentry-dart/pull/3391))
    - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#8280)
    - [diff](https://github.com/getsentry/sentry-java/compare/8.21.1...8.28.0)
## 9.9.0-beta.4

### Fixes

- Dart to native type conversion ([#3372](https://github.com/getsentry/sentry-dart/pull/3372))
- Revert FFI usage on iOS/macOS due to symbol stripping issues ([#3379](https://github.com/getsentry/sentry-dart/pull/3379))

### Dependencies

- Bump Android SDK from v8.21.1 to v8.28.0 ([#3391](https://github.com/getsentry/sentry-dart/pull/3391))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#8280)
  - [diff](https://github.com/getsentry/sentry-java/compare/8.21.1...8.28.0)
## 9.9.0-beta.3

### Features

- Add `Sentry.setAttributes` and `Sentry.removeAttribute` ([#3352](https://github.com/getsentry/sentry-dart/pull/3352))
  - These attributes are set at the scope level and apply to all logs (and later to metrics and spans).
  - When a scope attribute conflicts with a log-level attribute, the log-level attribute always takes precedence.
- Sentry Supabase Integration ([#2913](https://github.com/getsentry/sentry-dart/pull/2913))
  - Adds the `sentry_supabase` package to instrument supabase with Sentry breadcrumbs, traces and errors.

### Fixes

- Android app crashing on hot-restart in debug mode ([#3358](https://github.com/getsentry/sentry-dart/pull/3358))
- Dont use `Companion` in JNI calls and properly release JNI refs ([#3354](https://github.com/getsentry/sentry-dart/pull/3354))
  - This potentially fixes segfault crashes related to JNI

### Enhancements

- Flush logs if client/hub/sdk is closed ([#3335](https://github.com/getsentry/sentry-dart/pull/3335)
## 9.8.0-beta.1

### Fixes

- Added `consumerProguardFiles 'proguard-rules.pro'` to the debug build configuration to ensure ProGuard rules are consistently applied across both release and debug variants. ([#3339](https://github.com/getsentry/sentry-dart/pull/3339))

### Enhancements

- Refactor `captureReplay` and `setReplayConfig` to use FFI/JNI ([#3318](https://github.com/getsentry/sentry-dart/pull/3318))
- Refactor `init` to use FFI/JNI ([#3324](https://github.com/getsentry/sentry-dart/pull/3324))
## 9.8.0

### Features

- Mark file sync spans run in the main isolate with `blocked_main_thread` ([#3270](https://github.com/getsentry/sentry-dart/pull/3270))
 - This allows Sentry to create issues automatically out of file spans running a certain time on the main thread: https://docs.sentry.io/product/issues/issue-details/performance-issues/file-main-thread-io/

### Enhancements

- Refactor `setExtra` and `removeExtra` to use FFI/JNI ([#3314](https://github.com/getsentry/sentry-dart/pull/3314))
- Refactor `setTag` and `removeTag` to use FFI/JNI ([#3313](https://github.com/getsentry/sentry-dart/pull/3313))
- Refactor `setContexts` and `removeContexts` to use FFI/JNI ([#3312](https://github.com/getsentry/sentry-dart/pull/3312))
- Refactor `setUser` to use FFI/JNI ([#3295](https://github.com/getsentry/sentry-dart/pull/3295/))
- Refactor native breadcrumbs sync to use FFI/JNI ([#3293](https://github.com/getsentry/sentry-dart/pull/3293/))
- Refactor app hang and crash apis to use FFI/JNI ([#3289](https://github.com/getsentry/sentry-dart/pull/3289/))
- Refactor `AndroidReplayRecorder` to use the new worker isolate api ([#3296](https://github.com/getsentry/sentry-dart/pull/3296/))
- Refactor fetching app start and display refresh rate to use FFI and JNI ([#3288](https://github.com/getsentry/sentry-dart/pull/3288/))
- Offload `captureEnvelope` to background isolate for Cocoa and Android ([#3232](https://github.com/getsentry/sentry-dart/pull/3232))
- Add `sentry.replay_id` to flutter logs ([#3257](https://github.com/getsentry/sentry-dart/pull/3257))

### Fixes

- Fix unsafe json access in `sentry_device` ([#3309](https://github.com/getsentry/sentry-dart/pull/3309))
## 9.7.0

### Features

- Add W3C `traceparent` header support ([#3246](https://github.com/getsentry/sentry-dart/pull/3246))
    - Enable the option `propagateTraceparent` to allow the propagation of the W3C Trace Context HTTP header `traceparent` on outgoing HTTP requests.
- Add `nativeDatabasePath` option to `SentryFlutterOptions` to set the database path for Sentry Native ([#3236](https://github.com/getsentry/sentry-dart/pull/3236))
- Add `sentry.origin` to logs created by `LoggingIntegration` ([#3153](https://github.com/getsentry/sentry-dart/pull/3153))
- Tag all spans with thread info on non-web platforms ([#3101](https://github.com/getsentry/sentry-dart/pull/3101), [#3144](https://github.com/getsentry/sentry-dart/pull/3144))
- feat(feedback): Add option to disable keyboard resize ([#3154](https://github.com/getsentry/sentry-dart/pull/3154))
- Support `firebase_remote_config: >=5.4.3 <7.0.0` ([#3213](https://github.com/getsentry/sentry-dart/pull/3213))

### Enhancements

- Prefix firebase remote config feature flags with `firebase:` ([#3258](https://github.com/getsentry/sentry-dart/pull/3258))
- Replay: continue processing if encountering `InheritedWidget` ([#3200](https://github.com/getsentry/sentry-dart/pull/3200))
    - Prevents false debug warnings when using [provider](https://pub.dev/packages/provider) for example which extensively uses `InheritedWidget`
- Add `DioException` response data to error breadcrumb ([#3164](https://github.com/getsentry/sentry-dart/pull/3164))
    - Bumped `dio` min verion to `5.2.0`
- Use FFI/JNI for `captureEnvelope` on iOS and Android ([#3115](https://github.com/getsentry/sentry-dart/pull/3115))
- Log a warning when dropping envelope items ([#3165](https://github.com/getsentry/sentry-dart/pull/3165))
- Call options.log for structured logs ([#3187](https://github.com/getsentry/sentry-dart/pull/3187))
- Remove async usage from `FlutterErrorIntegration` ([#3202](https://github.com/getsentry/sentry-dart/pull/3202))
- Tag all spans during app start with start type info ([#3190](https://github.com/getsentry/sentry-dart/pull/3190))
- Refactor `loadContexts` and `loadDebugImages` to use JNI and FFI ([#3224](https://github.com/getsentry/sentry-dart/pull/3224))
- Improve envelope conversion to `Uint8List` in `FileSystemTransport` ([#3147](https://github.com/getsentry/sentry-dart/pull/3147))

### Fixes

- Safely access browser `navigator.deviceMemory` ([#3268](https://github.com/getsentry/sentry-dart/pull/3268))
- Recursion in `openDatabase` when using `SentrySqfliteDatabaseFactory` ([#3231](https://github.com/getsentry/sentry-dart/pull/3231))
- Implement prefill logic in `SentryFeedbackWidget` for `useSentryUser` parameter to populate fields with current user data ([#3180](https://github.com/getsentry/sentry-dart/pull/3180))
- Structured Logs: Don't add template when there are no 'sentry.message.parameter.x' attributes ([#3219](https://github.com/getsentry/sentry-dart/pull/3219))

### Dependencies

- Bump Cocoa SDK from v8.55.1 to v8.56.2 ([#3276](https://github.com/getsentry/sentry-dart/pull/3276))
    - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8562)
    - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.55.1...8.56.2)
- Bump Android SDK from v8.20.0 to v8.21.1 ([#3243](https://github.com/getsentry/sentry-dart/pull/3243))
    - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#8211)
    - [diff](https://github.com/getsentry/sentry-java/compare/8.20.0...8.21.1)
- Pin `ffigen` to `19.0.0` and add `objective_c` version `8.0.0` package used in `ffigen` on iOS and macOS ([#3163](https://github.com/getsentry/sentry-dart/pull/3163))
- Bump JavaScript SDK from v9.40.0 to v10.6.0 ([#3167](https://github.com/getsentry/sentry-dart/pull/3167), [#3201](https://github.com/getsentry/sentry-dart/pull/3201))
    - [changelog](https://github.com/getsentry/sentry-javascript/blob/develop/CHANGELOG.md#1060)
    - [diff](https://github.com/getsentry/sentry-javascript/compare/9.40.0...10.6.0)
- Bump Native SDK from v0.9.1 to v0.10.0 ([#3223](https://github.com/getsentry/sentry-dart/pull/3223))
    - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#0100)
    - [diff](https://github.com/getsentry/sentry-native/compare/0.9.1...0.10.0)
## 9.7.0-beta.5

### Dependencies

- Bump Android SDK from v8.20.0 to v8.21.1 ([#3243](https://github.com/getsentry/sentry-dart/pull/3243))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#8211)
  - [diff](https://github.com/getsentry/sentry-java/compare/8.20.0...8.21.1)
- Bump Cocoa SDK from v8.54.0 to v8.55.1 ([#3234](https://github.com/getsentry/sentry-dart/pull/3234))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8551)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.54.0...8.55.1)
## 9.7.0-beta.4

### Features

- Add `nativeDatabasePath` option to `SentryFlutterOptions` to set the database path for Sentry Native ([#3236](https://github.com/getsentry/sentry-dart/pull/3236))
## 9.7.0-beta.3

### Fixes

- Recursion in `openDatabase` when using `SentrySqfliteDatabaseFactory` ([#3231](https://github.com/getsentry/sentry-dart/pull/3231))

### Enhancements

- Replay: continue processing if encountering `InheritedWidget` ([#3200](https://github.com/getsentry/sentry-dart/pull/3200))
  - Prevents false debug warnings when using [provider](https://pub.dev/packages/provider) for example which extensively uses `InheritedWidget`
## 9.7.0-beta.2

### Features

- Add `sentry.origin` to logs created by `LoggingIntegration` ([#3153](https://github.com/getsentry/sentry-dart/pull/3153))
- Tag all spans with thread info on non-web platforms ([#3101](https://github.com/getsentry/sentry-dart/pull/3101), [#3144](https://github.com/getsentry/sentry-dart/pull/3144))
- feat(feedback): Add option to disable keyboard resize ([#3154](https://github.com/getsentry/sentry-dart/pull/3154))
- Support `firebase_remote_config: >=5.4.3 <7.0.0` ([#3213](https://github.com/getsentry/sentry-dart/pull/3213))

### Fixes

- Implement prefill logic in `SentryFeedbackWidget` for `useSentryUser` parameter to populate fields with current user data ([#3180](https://github.com/getsentry/sentry-dart/pull/3180))
- Structured Logs: Don’t add template when there are no 'sentry.message.parameter.x’ attributes ([#3219](https://github.com/getsentry/sentry-dart/pull/3219))

### Enhancements

- Add `DioException` response data to error breadcrumb ([#3164](https://github.com/getsentry/sentry-dart/pull/3164))
  - Bumped `dio` min verion to `5.2.0`
- Use FFI/JNI for `captureEnvelope` on iOS and Android ([#3115](https://github.com/getsentry/sentry-dart/pull/3115))
- Log a warning when dropping envelope items ([#3165](https://github.com/getsentry/sentry-dart/pull/3165))
- Call options.log for structured logs ([#3187](https://github.com/getsentry/sentry-dart/pull/3187))
- Remove async usage from `FlutterErrorIntegration` ([#3202](https://github.com/getsentry/sentry-dart/pull/3202))
- Tag all spans during app start with start type info ([#3190](https://github.com/getsentry/sentry-dart/pull/3190))
- Refactor `loadContexts` and `loadDebugImages` to use JNI and FFI ([#3224](https://github.com/getsentry/sentry-dart/pull/3224))

### Dependencies

- Pin `ffigen` to `19.0.0` and add `objective_c` version `8.0.0` package used in `ffigen` on iOS and macOS ([#3163](https://github.com/getsentry/sentry-dart/pull/3163))
- Bump Android SDK from v8.18.0 to v8.20.0 ([#3196](https://github.com/getsentry/sentry-dart/pull/3196))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#8200)
  - [diff](https://github.com/getsentry/sentry-java/compare/8.18.0...8.20.0)
- Bump JavaScript SDK from v9.40.0 to v10.6.0 ([#3167](https://github.com/getsentry/sentry-dart/pull/3167), [#3201](https://github.com/getsentry/sentry-dart/pull/3201))
  - [changelog](https://github.com/getsentry/sentry-javascript/blob/develop/CHANGELOG.md#1060)
  - [diff](https://github.com/getsentry/sentry-javascript/compare/9.40.0...10.6.0)
- Bump Native SDK from v0.9.1 to v0.10.0 ([#3223](https://github.com/getsentry/sentry-dart/pull/3223))
  - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#0100)
  - [diff](https://github.com/getsentry/sentry-native/compare/0.9.1...0.10.0)
## 9.7.0-beta.1

### Features

- Tag all spans with thread info ([#3101](https://github.com/getsentry/sentry-dart/pull/3101))

### Enhancements

- Improve envelope conversion to `Uint8List` in `FileSystemTransport` ([#3147](https://github.com/getsentry/sentry-dart/pull/3147))

### Dependencies

- Bump Cocoa SDK from v8.52.1 to v8.54.0 ([#3149](https://github.com/getsentry/sentry-dart/pull/3149/))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8540)
  - [diff](https://github.com/getsentry/sentry-java/compare/8.52.1...8.54.0)
- Bump Android SDK from v8.17.0 to v8.18.0 ([#3150](https://github.com/getsentry/sentry-dart/pull/3150))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#8180)
  - [diff](https://github.com/getsentry/sentry-java/compare/8.17.0...8.18.0)
## 9.6.0

Note: this release might require updating your Android Gradle Plugin version to at least `8.1.4`.

### Fixes

- False replay config restarts because of `ScreenshotWidgetStatus` equality issues ([#3114](https://github.com/getsentry/sentry-dart/pull/3114))
- Debug meta not loaded for split debug info only builds ([#3104](https://github.com/getsentry/sentry-dart/pull/3104))
- TTID/TTFD root transactions ([#3099](https://github.com/getsentry/sentry-dart/pull/3099), [#3111](https://github.com/getsentry/sentry-dart/pull/3111))
  - Web, Linux and Windows now create a UI transaction for the root page
  - iOS, Android now correctly create idle transactions
  - Fixes behaviour of traceId generation and TTFD for app start
- Directionality assertion issue in debug mode ([#3088](https://github.com/getsentry/sentry-dart/pull/3088))

### Dependencies

- Bump JNI from v0.14.1 to v0.14.2 ([#3075](https://github.com/getsentry/sentry-dart/pull/3075))
- Bump Android SDK from v8.13.2 to v8.17.0 ([#2977](https://github.com/getsentry/sentry-dart/pull/2977))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#8170)
  - [diff](https://github.com/getsentry/sentry-java/compare/8.13.2...8.17.0)

### Internal

- Use lifecycle hook for before send event ([#3017](https://github.com/getsentry/sentry-dart/pull/3017))
## 9.6.0-beta.2

### Fixes

- False replay config restarts because of `ScreenshotWidgetStatus` equality issues ([#3114](https://github.com/getsentry/sentry-dart/pull/3114))
## 9.6.0-beta.1

### Fixes

- Debug meta not loaded for split debug info only builds ([#3104](https://github.com/getsentry/sentry-dart/pull/3104))
- TTID/TTFD root transactions ([#3099](https://github.com/getsentry/sentry-dart/pull/3099), [#3111](https://github.com/getsentry/sentry-dart/pull/3111))
  - Web, Linux and Windows now create a UI transaction for the root page
  - iOS, Android now correctly create idle transactions
  - Fixes behaviour of traceId generation and TTFD for app start
- Directionality assertion issue in debug mode ([#3088](https://github.com/getsentry/sentry-dart/pull/3088))

### Dependencies

- Bump JNI from v0.14.1 to v0.14.2 ([#3075](https://github.com/getsentry/sentry-dart/pull/3075))
- Bump Android SDK from v8.13.2 to v8.17.0 ([#2977](https://github.com/getsentry/sentry-dart/pull/2977))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#8170)
  - [diff](https://github.com/getsentry/sentry-java/compare/8.13.2...8.17.0)

### Internal

- Use lifecycle hook for before send event ([#3017](https://github.com/getsentry/sentry-dart/pull/3017))
## 9.5.0

### Features

- Report Flutter framework feature flags ([#2991](https://github.com/getsentry/sentry-dart/pull/2991))
  - Search for feature flags that are prefixed with `flutter:*`
  - This works on Flutter builds that include [this PR](https://github.com/flutter/flutter/pull/171545)
- Add `LoggingIntegration` support for `SentryLog` ([#3050](https://github.com/getsentry/sentry-dart/pull/3050))
- Add `enableNewTraceOnNavigation` flag to `SentryNavigatorObserver` ([#3096](https://github.com/getsentry/sentry-dart/pull/3096))
  - **Default:** `true`
  - **Disable** by passing `false`, e.g.:
    ```dart
    SentryNavigatorObserver(enableNewTraceOnNavigation: false)
    ```
  - _Note: traces differ from transactions/spans — see tracing concepts [here](https://docs.sentry.io/concepts/key-terms/tracing/)_

### Fixes

- Ensure consistent sampling per trace ([#3079](https://github.com/getsentry/sentry-dart/pull/3079))

### Enhancements

- Add sampled flag in propagation context ([#3084](https://github.com/getsentry/sentry-dart/pull/3084))

### Dependencies

- Bump Native SDK from v0.9.0 to v0.9.1 ([#3018](https://github.com/getsentry/sentry-dart/pull/3018))
  - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#091)
  - [diff](https://github.com/getsentry/sentry-native/compare/0.9.0...0.9.1)
- Bump JavaScript SDK from v9.5.0 to v9.40.0 ([#3085](https://github.com/getsentry/sentry-dart/pull/3085), [#3092](https://github.com/getsentry/sentry-dart/pull/3092))
  - [changelog](https://github.com/getsentry/sentry-javascript/blob/develop/CHANGELOG.md#9400)
  - [diff](https://github.com/getsentry/sentry-javascript/compare/9.5.0...9.40.0)
## Internal

- Automate Sentry JS SDK version updates ([#3080](https://github.com/getsentry/sentry-dart/pull/3080))
## 9.4.1

### Fixes

- Span ids not re-generating for headers created from scope ([#3051](https://github.com/getsentry/sentry-dart/pull/3051))
- `ScreenshotIntegration` not being added for web ([#3055](https://github.com/getsentry/sentry-dart/pull/3055))
- `PropagationContext` not being set when `Scope` is cloned resulting in different trace ids when using `withScope` ([#3069](https://github.com/getsentry/sentry-dart/pull/3069))
- Drift transaction rollback not executed when parent span is null ([#3062](https://github.com/getsentry/sentry-dart/pull/3062))

### Enhancements

- Remove `SentryTimingsCallback` and use Flutter's `TimingsCallback` instead ([#3054](https://github.com/getsentry/sentry-dart/pull/3054))
- Remove unused native frames integration ([#3053](https://github.com/getsentry/sentry-dart/pull/3053))
## 9.4.0

### Fixes

- SPM should use `exact` instead of `from` when defining the sentry-cocoa package ([#3065](https://github.com/getsentry/sentry-dart/pull/3065))
- Respect ancestor text direction in `SentryScreenshotWidget` ([#3046](https://github.com/getsentry/sentry-dart/pull/3046))
- Add additional crashpad path candidate ([#3016](https://github.com/getsentry/sentry-dart/pull/3016))
- Replay JNI usage with `SentryFlutterPlugin` ([#3036](https://github.com/getsentry/sentry-dart/pull/3036), [#3039](https://github.com/getsentry/sentry-dart/pull/3039))
- Do not set `isTerminating` on `captureReplay` for Android ([#3037](https://github.com/getsentry/sentry-dart/pull/3037))
  - Previously segments might be missing on Android replays if an unhandled error happened

### Dependencies

- Bump Android SDK from v8.12.0 to v8.13.2 ([#3042](https://github.com/getsentry/sentry-dart/pull/3042))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#8132)
  - [diff](https://github.com/getsentry/sentry-java/compare/8.12.0...8.13.2)
## 9.4.0-beta.2

### Fixes

- Respect ancestor text direction in `SentryScreenshotWidget` ([#3046](https://github.com/getsentry/sentry-dart/pull/3046))
## 9.4.0-beta.1

### Fixes

- Add additional crashpad path candidate ([#3016](https://github.com/getsentry/sentry-dart/pull/3016))
- Replay JNI usage with `SentryFlutterPlugin` ([#3036](https://github.com/getsentry/sentry-dart/pull/3036), [#3039](https://github.com/getsentry/sentry-dart/pull/3039))
- Do not set `isTerminating` on `captureReplay` for Android ([#3037](https://github.com/getsentry/sentry-dart/pull/3037))
  - Previously segments might be missing on Android replays if an unhandled error happened

### Dependencies

- Bump Android SDK from v8.12.0 to v8.13.2 ([#3042](https://github.com/getsentry/sentry-dart/pull/3042))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#8132)
  - [diff](https://github.com/getsentry/sentry-java/compare/8.12.0...8.13.2)
## 9.3.0

### Breaking Change (Tooling)

- Upgrade Kotlin `languageVersion` to `1.8` ([#3032](https://github.com/getsentry/sentry-dart/pull/3032))
  - This allows usage of the Kotlin Android Plugin `2.2.0` which requires a `languageVersion` of `1.8` or higher
  - If you are experiencing an issue we recommend upgrading to a toolchain compatible with Kotlin `1.8` or higher

### Features

- SentryFeedbackWidget Improvements ([#2964](https://github.com/getsentry/sentry-dart/pull/2964))
  - Capture a device screenshot for feedback
  - Customize tests and required fields
  - Customization moved from the `SentryFeedbackWidget` constructor to `SentryFlutterOptions`:
```dart
// configure your feedback widget
options.feedback.showBranding = false;
```
## 9.2.0

### Features

- Add os and device attributes to Flutter logs ([#2978](https://github.com/getsentry/sentry-dart/pull/2978))
- String templating for structured logs ([#3002](https://github.com/getsentry/sentry-dart/pull/3002))
- Add user attributes to Dart/Flutter logs ([#3014](https://github.com/getsentry/sentry-dart/pull/3002))

### Fixes

- Fix context to native sync for sentry context types ([#3012](https://github.com/getsentry/sentry-dart/pull/3012))

### Enhancements

- Dont execute app start integration if tracing is disabled ([#3026](https://github.com/getsentry/sentry-dart/pull/3026))
- Set Firebase Remote Config flags on integration initialization ([#3008](https://github.com/getsentry/sentry-dart/pull/3008))
## 9.1.0

### Features

- Flutter Web: add debug ids to events ([#2917](https://github.com/getsentry/sentry-dart/pull/2917))
  - This allows support for symbolication based on [debug ids](https://docs.sentry.io/platforms/javascript/sourcemaps/troubleshooting_js/debug-ids/)
  - This only works if you use the Sentry Dart Plugin version `3.0.0` or higher
- Improved TTID/TTFD API ([#2866](https://github.com/getsentry/sentry-dart/pull/2866))
  - This improves the stability and consistency of TTFD reporting by introducing new APIs
```dart
// Prerequisite: `SentryNavigatorObserver` is set up and routes you navigate to have unique names, e.g configured via `RouteSettings`
// Info: Stateless widgets will report TTFD automatically when wrapped with `SentryDisplayWidget` - no need to call `reportFullyDisplayed`.

// Method 1: wrap your widget that you navigate to in `SentryDisplayWidget` 
SentryDisplayWidget(child: YourWidget())

// Then report TTFD after long running work (File I/O, Network) within your widget.
@override
void initState() {
  super.initState();
  // Do some long running work...
  Future.delayed(const Duration(seconds: 3), () {
    if (mounted) {
      SentryDisplayWidget.of(context).reportFullyDisplayed();
    }
  });
}

// Method 2: use the API directly to report TTFD - this does not require wrapping your widget with `SentryDisplayWidget`:
@override
void initState() {
  super.initState();
  // Get a reference to the current display before doing work.
  final currentDisplay = SentryFlutter.currentDisplay();
  // Do some long running work...
  Future.delayed(const Duration(seconds: 3), () {
    currentDisplay?.reportFullyDisplayed();
  });
}
```
- Add `message` parameter to `captureException()` ([#2882](https://github.com/getsentry/sentry-dart/pull/2882))
- Add module in SentryStackFrame ([#2931](https://github.com/getsentry/sentry-dart/pull/2931))
  - Set `SentryOptions.includeModuleInStackTrace = true` to enable this. This may change grouping of exceptions.

### Dependencies

- Bump Cocoa SDK from v8.51.0 to v8.52.1 ([#2981](https://github.com/getsentry/sentry-dart/pull/2981))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8521)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.51.0...8.52.1)
- Bump Native SDK from v0.8.4 to v0.9.0 ([#2980](https://github.com/getsentry/sentry-dart/pull/2980))
  - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#090)
  - [diff](https://github.com/getsentry/sentry-native/compare/0.8.4...0.9.0)

### Enhancements

- Only enable load debug image integration for obfuscated apps ([#2907](https://github.com/getsentry/sentry-dart/pull/2907))
## 9.0.0

Version 9.0.0 marks a major release of the Sentry Dart/Flutter SDKs containing breaking changes.

The goal of this release is the following:
 - Bump the minimum Dart and Flutter versions to `3.5.0` and `3.24.0` respectively
 - Bump the minimum Android API version to 21
 - Add interoperability with the Sentry Javascript SDK in Flutter Web for features such as release health and reporting native JS errors
 - GA the [Session Replay](https://docs.sentry.io/product/explore/session-replay/) feature
 - Provide feature flag support as well as [Firebase Remote Config](https://firebase.google.com/docs/remote-config) support
 - Trim down unused and potentially confusing APIs

### How To Upgrade

Please carefully read through the migration guide in the Sentry docs on how to upgrade from version 8 to version 9
 - [Dart migration guide](https://docs.sentry.io/platforms/dart/migration/#migrating-from-sentry-8x-to-sentry-9x)
 - [Flutter migration guide](https://docs.sentry.io/platforms/dart/guides/flutter/migration/#migrating-from-sentry_flutter-8x-to-sentry_flutter-9x)

### Breaking changes

- Increase minimum SDK version requirements to Dart `v3.5.0` and Flutter `v3.24.0` ([#2643](https://github.com/getsentry/sentry-dart/pull/2643))
- Update naming of `LoadImagesListIntegration` to `LoadNativeDebugImagesIntegration` ([#2833](https://github.com/getsentry/sentry-dart/pull/2833))
- Set sentry-native backend to `crashpad` by default and `breakpad` for Windows ARM64 ([#2791](https://github.com/getsentry/sentry-dart/pull/2791))
  - Setting the `SENTRY_NATIVE_BACKEND` environment variable will override the defaults.
- Remove manual TTID implementation ([#2668](https://github.com/getsentry/sentry-dart/pull/2668))
- Remove screenshot option `attachScreenshotOnlyWhenResumed` ([#2664](https://github.com/getsentry/sentry-dart/pull/2664))
- Remove deprecated `beforeScreenshot` ([#2662](https://github.com/getsentry/sentry-dart/pull/2662))
- Remove old user feedback api ([#2686](https://github.com/getsentry/sentry-dart/pull/2686))
  - This is replaced by `beforeCaptureScreenshot`
- Remove deprecated loggers ([#2685](https://github.com/getsentry/sentry-dart/pull/2685))
- Remove user segment ([#2687](https://github.com/getsentry/sentry-dart/pull/2687))
- Enable Sentry JS SDK native integration by default ([#2688](https://github.com/getsentry/sentry-dart/pull/2688))
- Remove `enableTracing` ([#2695](https://github.com/getsentry/sentry-dart/pull/2695))
- Remove `options.autoAppStart` and `setAppStartEnd` ([#2680](https://github.com/getsentry/sentry-dart/pull/2680))
- Bump Drift min version to `2.24.0` and use `QueryInterceptor` instead of `QueryExecutor` ([#2679](https://github.com/getsentry/sentry-dart/pull/2679))
- Add hint for transactions ([#2675](https://github.com/getsentry/sentry-dart/pull/2675))
  - `BeforeSendTransactionCallback` now has a `Hint` parameter
- Remove `dart:html` usage in favour of `package:web` ([#2710](https://github.com/getsentry/sentry-dart/pull/2710))
- Remove max response body size ([#2709](https://github.com/getsentry/sentry-dart/pull/2709))
  - Responses are now only attached if size is below ~0.15mb
  - Responses are attached to the `Hint` object, which can be read in `beforeSend`/`beforeSendTransaction` callbacks via `hint.response`.
  - For now, only the `dio` integration is supported.
- Enable privacy masking for screenshots by default ([#2728](https://github.com/getsentry/sentry-dart/pull/2728))
- Set option `anrEnabled` to `true` by default (#2878)
- Mutable Data Classes ([#2818](https://github.com/getsentry/sentry-dart/pull/2818))
  - Some SDK classes do not have `const` constructors anymore.
  - The `copyWith` and `clone` methods of SDK classes were deprecated.
```dart
// old
options.beforeSend = (event, hint) {
  event = event.copyWith(release: 'my-release');
  return event;
}
// new
options.beforeSend = (event, hint) {
  event.release = 'my-release';
  return event;
}
```

### Features

- Sentry Structured Logs Beta ([#2919](https://github.com/getsentry/sentry-dart/pull/2919))
  - The old `SentryLogger` has been renamed to `SdkLogCallback` and can be accessed through `options.log` now.
  - Adds support for structured logging though `Sentry.logger`:
```dart
// Enable in `SentryOptions`:
options.enableLogs = true;

// Use `Sentry.logger`
Sentry.logger.info("This is a info log.");
Sentry.logger.warn("This is a warning log with attributes.", attributes: {
  'string-attribute': SentryLogAttribute.string('string'),
  'int-attribute': SentryLogAttribute.int(1),
  'double-attribute': SentryLogAttribute.double(1.0),
  'bool-attribute': SentryLogAttribute.bool(true),
});
```
- Add support for feature flags and integration with Firebase Remote Config ([#2825](https://github.com/getsentry/sentry-dart/pull/2825), [#2837](https://github.com/getsentry/sentry-dart/pull/2837))
```dart
// Manually track a feature flag
Sentry.addFeatureFlag('my-feature', true);

// or use the Sentry Firebase Remote Config Integration (sentry_firebase_remote_config package is required)
// Add the integration to automatically track feature flags from firebase remote config.
await SentryFlutter.init(
  (options) {
    options.dsn = 'https://example@sentry.io/add-your-dsn-here';
    options.addIntegration(
      SentryFirebaseRemoteConfigIntegration(
        firebaseRemoteConfig: yourFirebaseRemoteConfig,
      ),
    );
  },
);
```
- Properly generates and links trace IDs for errors and spans ([#2869](https://github.com/getsentry/sentry-dart/pull/2869), [#2861](https://github.com/getsentry/sentry-dart/pull/2861)):
  - **With `SentryNavigatorObserver`** - each navigation event starts a new trace.
  - **Without `SentryNavigatorObserver` on non-web platforms** - a new trace is started from app
    lifecycle hooks.
  - **Web without `SentryNavigatorObserver`** - the same trace ID is reused until the page is
    refreshed or closed.
- Add support for Flutter Web release health ([#2794](https://github.com/getsentry/sentry-dart/pull/2794))
  - Requires using `SentryNavigatorObserver`;

### Behavioral changes

- Set log level to `warning` by default when `debug = true` ([#2836](https://github.com/getsentry/sentry-dart/pull/2836))
- Set HTTP client breadcrumbs log level based on response status code ([#2847](https://github.com/getsentry/sentry-dart/pull/2847))
  - 5xx is mapped to `SentryLevel.error`
  - 4xx is mapped to `SentryLevel.warning`
- Parent-child relationship for the PlatformExceptions and Cause ([#2803](https://github.com/getsentry/sentry-dart/pull/2803))
  - Improves and more accurately represent exception groups
  - Disabled by default as it may cause issues to group differently
  - You can enable this feature by setting `options.groupException = true`

### Improvements

- Replay: improve Android native interop performance by using JNI ([#2670](https://github.com/getsentry/sentry-dart/pull/2670))
- Align User Feedback API ([#2949](https://github.com/getsentry/sentry-dart/pull/2949))
  - Don’t apply breadcrumbs and extras from scope to feedback events
  - Capture session replay when processing feedback events
  - Record `feedback` client report for dropped feedback events
  - Record `feedback` client report for errors when using `HttpTransport`
- Truncate feedback message to max 4096 characters ([#2954](https://github.com/getsentry/sentry-dart/pull/2954))
- Replay: Mask RichText Widgets by default ([#2975](https://github.com/getsentry/sentry-dart/pull/2975))

### Dependencies

- Bump Android SDK from v7.22.4 to v8.12.0 ([#2941](https://github.com/getsentry/sentry-dart/pull/2941), [#2819](https://github.com/getsentry/sentry-dart/pull/2819), [#2831](https://github.com/getsentry/sentry-dart/pull/2831), [#2848](https://github.com/getsentry/sentry-dart/pull/2848), [#2873](https://github.com/getsentry/sentry-dart/pull/2873, [#2883](https://github.com/getsentry/sentry-dart/pull/2883)))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#890)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.22.4...8.9.0)
- Bump Cocoa SDK from v8.46.0 to v8.51.0 ([#2820](https://github.com/getsentry/sentry-dart/pull/2820), [#2851](https://github.com/getsentry/sentry-dart/pull/2851), [#2884](https://github.com/getsentry/sentry-dart/pull/2884), [#2951](https://github.com/getsentry/sentry-dart/pull/2951)))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8491)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.46.0...8.49.1)
- Bump Native SDK from v0.8.2 to v0.8.4 ([#2823](https://github.com/getsentry/sentry-dart/pull/2823), [#2872](https://github.com/getsentry/sentry-dart/pull/2872))
  - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#084)
  - [diff](https://github.com/getsentry/sentry-native/compare/0.8.2...0.8.4)
- Bump jni from v0.14.0 to v0.14.1 ([#2800])(https://github.com/getsentry/sentry-dart/pull/2800)
  - [changelog](https://github.com/dart-lang/native/blob/main/pkgs/jni/CHANGELOG.md#0141)
  - [diff](https://github.com/dart-lang/native/compare/jnigen-v0.14.0..jnigen-v0.14.1)
## 9.0.0-RC.4

### Enhancements

- Replay: Mask RichText Widgets ([#2975](https://github.com/getsentry/sentry-dart/pull/2975))
## 9.0.0-RC.3

### Features

- Sentry Structured Logs ([#2919](https://github.com/getsentry/sentry-dart/pull/2919))
  - The old `SentryLogger` has been renamed to `SdkLogCallback` and can be accessed through `options.log` now.
  - Adds support for structured logging though `Sentry.logger`:
```dart
// Enable in `SentryOptions`:
options.enableLogs = true;

// Use `Sentry.logger`
Sentry.logger.info("This is a info log.");
Sentry.logger.warn("This is a warning log with attributes.", attributes: {
  'string-attribute': SentryLogAttribute.string('string'),
  'int-attribute': SentryLogAttribute.int(1),
  'double-attribute': SentryLogAttribute.double(1.0),
  'bool-attribute': SentryLogAttribute.bool(true),
});
```
## 9.0.0-RC.2

### Fixes

- Add `hasSize` guard when using a renderObject in `SentryUserInteractionWidget` ([#2946](https://github.com/getsentry/sentry-dart/pull/2946))
## 9.0.0-RC.1

### Fixes

- Fix feature flag model keys ([#2943](https://github.com/getsentry/sentry-dart/pull/2943))
## 9.0.0-RC

### Various fixes & improvements

- build(deps): bump ruby/setup-ruby from 1.233.0 to 1.237.0 (#2908) by @dependabot
- build(deps): bump actions/create-github-app-token from 2.0.2 to 2.0.6 (#2909) by @dependabot
## 9.0.0-beta.2

### Fixes

- Errors caught by `OnErrorIntegration` should be unhandled by default ([#2901](https://github.com/getsentry/sentry-dart/pull/2901))
  - This will not affect grouping
  - This might affect crash-free rate

### Dependencies

- Bump Android SDK from v8.9.0 to v8.11.1 ([#2899](https://github.com/getsentry/sentry-dart/pull/2899), [#2904](https://github.com/getsentry/sentry-dart/pull/2904))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#8111)
  - [diff](https://github.com/getsentry/sentry-java/compare/8.9.0...8.11.1)
- Bump Cocoa SDK from v8.49.1 to v8.49.2 ([#2905](https://github.com/getsentry/sentry-dart/pull/2905))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8492)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.49.1...8.49.2)
## 9.0.0-beta.1

### Features

- Properly generates and links trace IDs for errors and spans ([#2869](https://github.com/getsentry/sentry-dart/pull/2869), [#2861](https://github.com/getsentry/sentry-dart/pull/2861)):
  - **With `SentryNavigatorObserver`** - each navigation event starts a new trace.
  - **Without `SentryNavigatorObserver` on non-web platforms** - a new trace is started from app
    lifecycle hooks.
  - **Web without `SentryNavigatorObserver`** - the same trace ID is reused until the page is
    refreshed or closed.
- Add `FeatureFlagIntegration` ([#2825](https://github.com/getsentry/sentry-dart/pull/2825))
```dart
// Manually track a feature flag
Sentry.addFeatureFlag('my-feature', true);
```
- Firebase Remote Config Integration ([#2837](https://github.com/getsentry/sentry-dart/pull/2837))
```dart
// Add the integration to automatically track feature flags from firebase remote config.
await SentryFlutter.init(
  (options) {
    options.dsn = 'https://example@sentry.io/add-your-dsn-here';
    options.addIntegration(
      SentryFirebaseRemoteConfigIntegration(
        firebaseRemoteConfig: yourFirebaseRemoteConfig,
      ),
    );
  },
);
```
- Make hierarchical exception grouping opt-in ([#2858](https://github.com/getsentry/sentry-dart/pull/2858))


### Fixes

- Trace propagation in HTTP tracing clients not correctly set up if performance is disabled ([#2850](https://github.com/getsentry/sentry-dart/pull/2850))

### Behavioral changes

- Mutable Data Classes ([#2818](https://github.com/getsentry/sentry-dart/pull/2818))
  - Some SDK classes do not have `const` constructors anymore.
  - The `copyWith` and `clone` methods of SDK classes were deprecated.
- Set log level to `warning` by default when `debug = true` ([#2836](https://github.com/getsentry/sentry-dart/pull/2836))
- Set HTTP client breadcrumbs log level based on response status code ([#2847](https://github.com/getsentry/sentry-dart/pull/2847))
  - 5xx is mapped to `SentryLevel.error`
  - 4xx is mapped to `SentryLevel.warning`
- Parent-child relationship for the PlatformExceptions and Cause ([#2803](https://github.com/getsentry/sentry-dart/pull/2803), [#2858](https://github.com/getsentry/sentry-dart/pull/2858))
  - Improves and changes exception grouping. To opt in, set `groupExceptions=true`
- Set `anrEnabled` enabled per default ([#2878](https://github.com/getsentry/sentry-dart/pull/2878))

### API Changes

- Update naming of `LoadImagesListIntegration` to `LoadNativeDebugImagesIntegration` ([#2833](https://github.com/getsentry/sentry-dart/pull/2833))
- Remove `other` from `SentryRequest` ([#2879](https://github.com/getsentry/sentry-dart/pull/2879))

### Dependencies

- Bump Android SDK from v8.2.0 to v8.9.0 ([#2819](https://github.com/getsentry/sentry-dart/pull/2819), [#2831](https://github.com/getsentry/sentry-dart/pull/2831), [#2848](https://github.com/getsentry/sentry-dart/pull/2848), [#2873](https://github.com/getsentry/sentry-dart/pull/2873), [#2883](https://github.com/getsentry/sentry-dart/pull/2883))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#890)
  - [diff](https://github.com/getsentry/sentry-java/compare/8.2.0...8.9.0)
- Bump Cocoa SDK from v8.46.0 to v8.49.1 ([#2820](https://github.com/getsentry/sentry-dart/pull/2820), [#2851](https://github.com/getsentry/sentry-dart/pull/2851), [#2884](https://github.com/getsentry/sentry-dart/pull/2884))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8491)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.46.0...8.49.1)
- Bump Native SDK from v0.8.2 to v0.8.4 ([#2823](https://github.com/getsentry/sentry-dart/pull/2823), [#2872](https://github.com/getsentry/sentry-dart/pull/2872))
  - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#084)
  - [diff](https://github.com/getsentry/sentry-native/compare/0.8.2...0.8.4)
- Bump jni from v0.14.0 to v0.14.1 ([#2800])(https://github.com/getsentry/sentry-dart/pull/2800)
  - [changelog](https://github.com/dart-lang/native/blob/main/pkgs/jni/CHANGELOG.md#0141)
  - [diff](https://github.com/dart-lang/native/compare/jnigen-v0.14.0..jnigen-v0.14.1)
## 9.0.0-alpha.2

### Features

- Add support for Flutter Web release health ([#2794](https://github.com/getsentry/sentry-dart/pull/2794))
  - Requires using `SentryNavigatorObserver`;
 
### Dependencies

- Bump Native SDK from v0.7.20 to v0.8.2 ([#2761](https://github.com/getsentry/sentry-dart/pull/2761), [#2807](https://github.com/getsentry/sentry-dart/pull/2807))
  - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#082)
  - [diff](https://github.com/getsentry/sentry-native/compare/0.7.20...0.8.2)
- Bump Javascript SDK from v8.42.0 to v9.5.0 ([#2784](https://github.com/getsentry/sentry-dart/pull/2784))
  - [changelog](https://github.com/getsentry/sentry-javascript/blob/main/CHANGELOG.md#950)
  - [diff](https://github.com/getsentry/sentry-javascript/compare/8.42.0...9.5.0)

### Behavioral changes

- Set sentry-native backend to `crashpad` by default and `breakpad` for Windows ARM64 ([#2791](https://github.com/getsentry/sentry-dart/pull/2791))
  - Setting the `SENTRY_NATIVE_BACKEND` environment variable will override the defaults.
- Remove renderer from `flutter_context` ([#2751](https://github.com/getsentry/sentry-dart/pull/2751))
  
### API changes

- Move replay and privacy from experimental to options ([#2755](https://github.com/getsentry/sentry-dart/pull/2755))
- Cleanup platform mocking ([#2730](https://github.com/getsentry/sentry-dart/pull/2730))
  - The `PlatformChecker` was renamed to `RuntimeChecker`
  - Moved `PlatformChecker.platform` to `options.platform`
## 9.0.0-alpha.1

### Breaking changes

- Remove `SentryDisplayWidget` and manual TTID implementation ([#2668](https://github.com/getsentry/sentry-dart/pull/2668))
- Increase minimum SDK version requirements to Dart v3.5.0 and Flutter v3.24.0 ([#2643](https://github.com/getsentry/sentry-dart/pull/2643))
- Remove screenshot option `attachScreenshotOnlyWhenResumed` ([#2664](https://github.com/getsentry/sentry-dart/pull/2664))
- Remove deprecated `beforeScreenshot` ([#2662](https://github.com/getsentry/sentry-dart/pull/2662))
- Remove old user feedback api ([#2686](https://github.com/getsentry/sentry-dart/pull/2686))
- Remove deprecated loggers ([#2685](https://github.com/getsentry/sentry-dart/pull/2685))
- Remove user segment ([#2687](https://github.com/getsentry/sentry-dart/pull/2687))
- Enable JS SDK native integration by default ([#2688](https://github.com/getsentry/sentry-dart/pull/2688))
- Remove `enableTracing` ([#2695](https://github.com/getsentry/sentry-dart/pull/2695))
- Remove `options.autoAppStart` and `setAppStartEnd` ([#2680](https://github.com/getsentry/sentry-dart/pull/2680))
- Bump Drift min version to `2.24.0` and use `QueryInterceptor` instead of `QueryExecutor` ([#2679](https://github.com/getsentry/sentry-dart/pull/2679))
- Add hint for transactions ([#2675](https://github.com/getsentry/sentry-dart/pull/2675))
  - `BeforeSendTransactionCallback` now has a `Hint` parameter
- Remove `dart:html` usage in favour of `package:web` ([#2710](https://github.com/getsentry/sentry-dart/pull/2710))
- Remove max response body size ([#2709](https://github.com/getsentry/sentry-dart/pull/2709))
  - Responses are now only attached if size is below ~0.15mb
  - Responses are attached to the `Hint` object, which can be read in `beforeSend`/`beforeSendTransaction` callbacks via `hint.response`.
  - For now, only the `dio` integration is supported.
- Enable privacy masking for screenshots by default ([#2728](https://github.com/getsentry/sentry-dart/pull/2728))
  
### Enhancements

- Replay: improve Android native interop performance by using JNI ([#2670](https://github.com/getsentry/sentry-dart/pull/2670))

### Dependencies

- Bump Android SDK from v7.20.1 to v8.1.0 ([#2650](https://github.com/getsentry/sentry-dart/pull/2650))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#810)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.20.1...8.1.0)

## Older versions

Entries for versions before 9.0.0 are in [CHANGELOG-archive.md](https://github.com/getsentry/sentry-dart/blob/main/CHANGELOG-archive.md).
