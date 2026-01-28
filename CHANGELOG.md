# Changelog

## Unreleased

### Fixes

- Catch client exceptions in HttpTransport.send ([#3490](https://github.com/getsentry/sentry-dart/pull/3490))

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

## 8.14.2

### Improvements

- Improve performance of frames tracking ([#2854](https://github.com/getsentry/sentry-dart/pull/2854))
- Clean up `getSpan()` log ([#2865](https://github.com/getsentry/sentry-dart/pull/2865))

### Fixes

- `options.diagnosticLevel` not affecting logs ([#2856](https://github.com/getsentry/sentry-dart/pull/2856))

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

## 8.14.1

### Fixes

- Improve platform memory collection on windows/linux ([#2798](https://github.com/getsentry/sentry-dart/pull/2798))
  - Fixes an issue where total memory on windows was not read.
  - Free memory collection was removed on windows/linux, due to performance issues.
- Fix adding runtime to contexts ([#2813](https://github.com/getsentry/sentry-dart/pull/2813))

### Dependencies

- Bump Android SDK from v7.22.1 to v7.22.4 ([#2810](https://github.com/getsentry/sentry-dart/pull/2810))
  - [changelog](https://github.com/getsentry/sentry-java/blob/7.x.x/CHANGELOG.md#7224)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.22.1...7.22.4)

## 8.14.0

This release fixes an issue where Cold starts can be incorrectly reported as Warm starts on Android.

### Behavioral changes

- ⚠️ Auto IP assignment for `SentryUser` is now guarded by `sendDefaultPii` ([#2726](https://github.com/getsentry/sentry-dart/pull/2726))
  - If you rely on Sentry automatically processing the IP address of the user, set `options.sendDefaultPii = true` or manually set the IP address of the `SentryUser` to `{{auto}}`
- Adding the device name to Contexts is now guarded by `sendDefaultPii` ([#2741](https://github.com/getsentry/sentry-dart/pull/2741))
  - Set `options.sendDefaultPii = true` if you want to have the device name reported
- Remove macOS display refresh rate support ([#2628](https://github.com/getsentry/sentry-dart/pull/2628))
  - Can't reliably detect on multi-monitor systems and on older macOS versions.
  - Not very meaningful, as other applications may be running in parallel and affecting it.

### Enhancements

- Add Flutter runtime information ([#2742](https://github.com/getsentry/sentry-dart/pull/2742))
  - This works if the version of Flutter you're using includes [this code](https://github.com/flutter/flutter/pull/163761).
- Use `loadDebugImagesForAddresses` API for Android ([#2706](https://github.com/getsentry/sentry-dart/pull/2706))
  - This reduces the envelope size and data transferred across method channels
  - If debug images received by `loadDebugImagesForAddresses` are empty, the SDK loads all debug images as fallback
- Disable `ScreenshotIntegration`, `WidgetsBindingIntegration` and `SentryWidget` in multi-view apps #2366 ([#2366](https://github.com/getsentry/sentry-dart/pull/2366))

### Fixes

- Pass missing `captureFailedRequests` param to `FailedRequestInterceptor` ([#2744](https://github.com/getsentry/sentry-dart/pull/2744))
- Bind root screen transaction to scope ([#2756](https://github.com/getsentry/sentry-dart/pull/2756))
- Reference to `SentryWidgetsFlutterBinding` in warning message in `FramesTrackingIntegration` ([#2704](https://github.com/getsentry/sentry-dart/pull/2704))

### Deprecations

- Deprecate Drift `SentryQueryExecutor` ([#2715](https://github.com/getsentry/sentry-dart/pull/2715))
  - This will be replace by `SentryQueryInterceptor` in the next major v9
```dart
// Example usage in Sentry Flutter v9
final executor = NativeDatabase.memory().interceptWith(
  SentryQueryInterceptor(databaseName: 'your_db_name'),
);

final db = AppDatabase(executor);
```
- Deprecate `autoAppStart` and `setAppStartEnd` ([#2681](https://github.com/getsentry/sentry-dart/pull/2681))

### Dependencies

- Bump Native SDK from v0.7.19 to v0.7.20 ([#2652](https://github.com/getsentry/sentry-dart/pull/2652))
  - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#0720)
  - [diff](https://github.com/getsentry/sentry-native/compare/0.7.19...0.7.20)
- Bump Cocoa SDK from v8.44.0 to v8.46.0 ([#2772](https://github.com/getsentry/sentry-dart/pull/2772))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8460)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.44.0...8.46.0)

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

## 8.14.0-beta.1

### Behavioral changes

- ⚠️ Auto IP assignment for `SentryUser` is now guarded by `sendDefaultPii` ([#2726](https://github.com/getsentry/sentry-dart/pull/2726))
  - If you rely on Sentry automatically processing the IP address of the user, set `options.sendDefaultPii = true` or manually set the IP address of the `SentryUser` to `{{auto}}`
- Adding the device name to Contexts is now guarded by `sendDefaultPii` ([#2741](https://github.com/getsentry/sentry-dart/pull/2741))
  - Set `options.sendDefaultPii = true` if you want to have the device name reported

### Features

- Disable `ScreenshotIntegration`, `WidgetsBindingIntegration` and `SentryWidget` in multi-view apps #2366 ([#2366](https://github.com/getsentry/sentry-dart/pull/2366))

### Enhancements

- Use `loadDebugImagesForAddresses` API for Android ([#2706](https://github.com/getsentry/sentry-dart/pull/2706))
  - This reduces the envelope size and data transferred across method channels
  - If debug images received by `loadDebugImagesForAddresses` are empty, the SDK loads all debug images as fallback

### Fixes

- Reference to `SentryWidgetsFlutterBinding` in warning message in `FramesTrackingIntegration` ([#2704](https://github.com/getsentry/sentry-dart/pull/2704))

### Deprecations

- Deprecate Drift `SentryQueryExecutor` ([#2715](https://github.com/getsentry/sentry-dart/pull/2715))
  - This will be replace by `SentryQueryInterceptor` in the next major v9
```dart
// Example usage in Sentry Flutter v9
final executor = NativeDatabase.memory().interceptWith(
  SentryQueryInterceptor(databaseName: 'your_db_name'),
);

final db = AppDatabase(executor);
```
- Deprecate `autoAppStart` and `setAppStartEnd` ([#2681](https://github.com/getsentry/sentry-dart/pull/2681))

### Other

- Remove macOS display refresh rate support ([#2628](https://github.com/getsentry/sentry-dart/pull/2628))
  - Can't reliably detect on multi-monitor systems and on older macOS versions.
  - Not very meaningful, as other applications may be running in parallel and affecting it.

### Dependencies

- Bump Android SDK from v7.20.1 to v8.2.0 ([#2660](https://github.com/getsentry/sentry-dart/pull/2660), [#2713](https://github.com/getsentry/sentry-dart/pull/2713))
  - [changelog](https://github.com/getsentry/sentry-java/blob/7.x.x/CHANGELOG.md#820)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.20.1...8.2.0)
- Bump Native SDK from v0.7.19 to v0.7.20 ([#2652](https://github.com/getsentry/sentry-dart/pull/2652))
  - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#0720)
  - [diff](https://github.com/getsentry/sentry-native/compare/0.7.19...0.7.20)
- Bump Cocoa SDK from v8.44.0 to v8.45.0 ([#2718](https://github.com/getsentry/sentry-dart/pull/2718))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8450)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.44.0...8.45.0)

## 8.13.3

This release fixes an issue where Cold starts can be incorrectly reported as Warm starts on Android.

### Dependencies

- Bump Android SDK from v7.22.0 to v7.22.1 ([#2785](https://github.com/getsentry/sentry-dart/pull/2785))
  - [changelog](https://github.com/getsentry/sentry-java/blob/7.x.x/CHANGELOG.md#7221)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.22.0...7.22.1)

## 8.13.2

> [!WARNING]
> This release contains an issue where Cold starts can be incorrectly reported as Warm starts on Android. We recommend staying on version 8.12.0 if you use this feature on Android.
> See issue [#2769](https://github.com/getsentry/sentry-dart/issues/2769) for more details.

### Fixes

- `build_web_compiler` error ([#2736](https://github.com/getsentry/sentry-dart/pull/2736))
  - Use `if (dart.library.html)` instead of `if (dart.html)` for imports

## 8.13.1

> [!WARNING]
> This release contains an issue where Cold starts can be incorrectly reported as Warm starts on Android. We recommend staying on version 8.12.0 if you use this feature on Android.
> See issue [#2769](https://github.com/getsentry/sentry-dart/issues/2769) for more details.

### Fixes

- Replay video interruption if a `navigation` breadcrumb is missing `to` route info ([#2720](https://github.com/getsentry/sentry-dart/pull/2720))

### Dependencies

- Bump Android SDK from v7.20.1 to v7.22.0 ([#2705](https://github.com/getsentry/sentry-dart/pull/2705))
  - [changelog](https://github.com/getsentry/sentry-java/blob/7.x.x/CHANGELOG.md#7220)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.20.1...7.22.0)

## 8.13.0

> [!WARNING]
> This release contains an issue where Cold starts can be incorrectly reported as Warm starts on Android. We recommend staying on version 8.12.0 if you use this feature on Android.
> See issue [#2769](https://github.com/getsentry/sentry-dart/issues/2769) for more details.

### Breaking changes

- Remove Metrics API ([#2571](https://github.com/getsentry/sentry-dart/pull/2571))
  - The Metrics product never reached maturity from beta and has officially ended in October 7th, 2024
  - Read [this post](https://sentry.zendesk.com/hc/en-us/articles/26369339769883-Metrics-Beta-Ended-on-October-7th) for more information

### Features

- Add `beforeCapture` for View Hierarchy ([#2523](https://github.com/getsentry/sentry-dart/pull/2523))
  - View hierarchy calls are now debounced for 2 seconds.
- JS SDK integration ([#2572](https://github.com/getsentry/sentry-dart/pull/2572))
  - Enable the integration by setting `options.enableSentryJs = true`
  - Features:
    - Sending envelopes through Sentry JS transport layer
    - Capturing native JS errors
- Add SentryReplayQuality setting (`options.experimental.replay.quality`) ([#2582](https://github.com/getsentry/sentry-dart/pull/2582))
- SPM Support ([#2280](https://github.com/getsentry/sentry-dart/pull/2280))

### Enhancements

- Replay: improve iOS native interop performance ([#2530](https://github.com/getsentry/sentry-dart/pull/2530), [#2573](https://github.com/getsentry/sentry-dart/pull/2573))
- Replay: improve orientation change tracking accuracy on Android ([#2540](https://github.com/getsentry/sentry-dart/pull/2540))
- Print a warning if the rate limit was reached ([#2595](https://github.com/getsentry/sentry-dart/pull/2595))
- Add replay masking config to tags and report SDKs versions ([#2592](https://github.com/getsentry/sentry-dart/pull/2592))
- Enable `options.debug` when in debug mode ([#2597](https://github.com/getsentry/sentry-dart/pull/2597))
- Propagate sample seed in baggage header ([#2629](https://github.com/getsentry/sentry-dart/pull/2629))
  - Read more about the specs [here](https://develop.sentry.dev/sdk/telemetry/traces/#propagated-random-value)
- Finish and start new transaction when tapping same element again ([#2623](https://github.com/getsentry/sentry-dart/pull/2623))

### Fixes

- Replay: fix masking for frames captured during UI changes ([#2553](https://github.com/getsentry/sentry-dart/pull/2553), [#2657](https://github.com/getsentry/sentry-dart/pull/2657))
- Replay: fix widget masks overlap when navigating between screens ([#2486](https://github.com/getsentry/sentry-dart/pull/2486), [#2576](https://github.com/getsentry/sentry-dart/pull/2576))
- WASM compat for Drift ([#2580](https://github.com/getsentry/sentry-dart/pull/2580))
- Fix image flickering when using `SentryAssetBundle` ([#2577](https://github.com/getsentry/sentry-dart/pull/2577))
- Fix print recursion detection ([#2624](https://github.com/getsentry/sentry-dart/pull/2624))

### Misc

- Transfer ownership of `sentry_link` to Sentry. You can view the changelog for the previous versions [here](https://github.com/getsentry/sentry-dart/blob/main/link/CHANGELOG_OLD.md) ([#2338](https://github.com/getsentry/sentry-dart/pull/2338))
  - No functional changes have been made. This version is identical to the previous one.
  - Change license from Apache to MIT

### Dependencies

- Bump Native SDK from v0.7.17 to v0.7.19 ([#2578](https://github.com/getsentry/sentry-dart/pull/2578), [#2588](https://github.com/getsentry/sentry-dart/pull/2588))
  - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#0719)
  - [diff](https://github.com/getsentry/sentry-native/compare/0.7.17...0.7.19)
- Bump Android SDK from v7.19.0 to v7.20.1 ([#2536](https://github.com/getsentry/sentry-dart/pull/2536), [#2549](https://github.com/getsentry/sentry-dart/pull/2549), [#2593](https://github.com/getsentry/sentry-dart/pull/2593))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#7201)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.20.0...7.20.1)
- Bump Cocoa SDK from v8.42.0 to v8.44.0 ([#2542](https://github.com/getsentry/sentry-dart/pull/2542), [#2548](https://github.com/getsentry/sentry-dart/pull/2548), [#2598](https://github.com/getsentry/sentry-dart/pull/2598), [#2649](https://github.com/getsentry/sentry-dart/pull/2649))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8440)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.42.0...8.44.0)

## 8.13.0-beta.3

### Enhancements

- Enable `options.debug` when in debug mode ([#2597](https://github.com/getsentry/sentry-dart/pull/2597))

### Fixes

- Fix image flickering when using `SentryAssetBundle` ([#2577](https://github.com/getsentry/sentry-dart/pull/2577))

### Misc

- Transfer ownership of `sentry_link` to Sentry. You can view the changelog for the previous versions [here](https://github.com/getsentry/sentry-dart/blob/main/link/CHANGELOG_OLD.md) ([#2338](https://github.com/getsentry/sentry-dart/pull/2338))
  - No functional changes have been made. This version is identical to the previous one.
  - Change license from Apache to MIT

## 8.13.0-beta.2

### Features

- Add SentryReplayQuality setting (`options.experimental.replay.quality`) ([#2582](https://github.com/getsentry/sentry-dart/pull/2582))
- SPM Support ([#2280](https://github.com/getsentry/sentry-dart/pull/2280))

### Enhancements

- Print a warning if the rate limit was reached ([#2595](https://github.com/getsentry/sentry-dart/pull/2595))
- Add replay masking config to tags and report SDKs versions ([#2592](https://github.com/getsentry/sentry-dart/pull/2592))

### Fixes

- WASM compat for Drift ([#2580](https://github.com/getsentry/sentry-dart/pull/2580))

### Dependencies

- Bump Native SDK from v0.7.17 to v0.7.19 ([#2578](https://github.com/getsentry/sentry-dart/pull/2578), [#2588](https://github.com/getsentry/sentry-dart/pull/2588))
  - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#0719)
  - [diff](https://github.com/getsentry/sentry-native/compare/0.7.17...0.7.19)
- Bump Android SDK from v7.20.0 to v7.20.1 ([#2593](https://github.com/getsentry/sentry-dart/pull/2593))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#7201)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.20.0...7.20.1)
- Bump Cocoa SDK from v8.43.0 to v8.44.0-beta.1 ([#2598](https://github.com/getsentry/sentry-dart/pull/2598))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8440-beta1)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.43.0...8.44.0-beta.1)

## 8.13.0-beta.1

### Breaking changes

- Remove Metrics API ([#2571](https://github.com/getsentry/sentry-dart/pull/2571))
  - The Metrics product never reached maturity from beta and has officially ended in October 7th, 2024
  - Read [this post](https://sentry.zendesk.com/hc/en-us/articles/26369339769883-Metrics-Beta-Ended-on-October-7th) for more information

### Features

- Add `beforeCapture` for View Hierarchy ([#2523](https://github.com/getsentry/sentry-dart/pull/2523))
  - View hierarchy calls are now debounced for 2 seconds.
- JS SDK integration ([#2572](https://github.com/getsentry/sentry-dart/pull/2572))
  - Enable the integration by setting `options.enableSentryJs = true`
  - Features:
    - Sending envelopes through Sentry JS transport layer
    - Capturing native JS errors

### Enhancements

- Replay: improve iOS native interop performance ([#2530](https://github.com/getsentry/sentry-dart/pull/2530), [#2573](https://github.com/getsentry/sentry-dart/pull/2573))
- Replay: improve orientation change tracking accuracy on Android ([#2540](https://github.com/getsentry/sentry-dart/pull/2540))

### Fixes

- Replay: fix masking for frames captured during UI changes ([#2553](https://github.com/getsentry/sentry-dart/pull/2553))
- Replay: fix widget masks overlap when navigating between screens ([#2486](https://github.com/getsentry/sentry-dart/pull/2486), [#2576](https://github.com/getsentry/sentry-dart/pull/2576))

### Dependencies

- Bump Cocoa SDK from v8.42.0 to v8.43.0 ([#2542](https://github.com/getsentry/sentry-dart/pull/2542), [#2548](https://github.com/getsentry/sentry-dart/pull/2548))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8430)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.42.0...8.43.0)
- Bump Android SDK from v7.19.0 to v7.20.0 ([#2536](https://github.com/getsentry/sentry-dart/pull/2536), [#2549](https://github.com/getsentry/sentry-dart/pull/2549))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#7200)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.19.0...7.20.0)

## 8.12.0

### Deprecations

- Manual TTID ([#2477](https://github.com/getsentry/sentry-dart/pull/2477))

### Fixes

- Missing replay gestures on Android ([#2515](https://github.com/getsentry/sentry-dart/pull/2515))
- Replay mask sizing on scaling transform widget children ([#2520](https://github.com/getsentry/sentry-dart/pull/2520))
- Masking semi-transparent widgets ([#2472](https://github.com/getsentry/sentry-dart/pull/2472))
- Check `SentryTracer` type in TTFD tracker ([#2508](https://github.com/getsentry/sentry-dart/pull/2508))

### Features

- Replay: device orientation change support & improve video size fit on Android ([#2462](https://github.com/getsentry/sentry-dart/pull/2462))
- Support custom `Sentry.runZoneGuarded` zone creation ([#2088](https://github.com/getsentry/sentry-dart/pull/2088))
  - Sentry will not create a custom zone anymore if it is started within a custom one.
  - This fixes Zone miss-match errors when trying to initialize WidgetsBinding before Sentry on Flutter Web
  - `Sentry.runZonedGuarded` creates a zone and also captures exceptions & breadcrumbs automatically.

  ```dart
  Sentry.runZonedGuarded(() {
    WidgetsBinding.ensureInitialized();

    // Errors before init will not be handled by Sentry

    SentryFlutter.init(
      (options) {
      ...
      },
      appRunner: () => runApp(MyApp()),
    );
  }, (error, stackTrace) {
    // Automatically sends errors to Sentry, no need to do any
    // captureException calls on your part.
    // On top of that, you can do your own custom stuff in this callback.
  });
  ```

- Warning (in a debug build) if a potentially sensitive widget is not masked or unmasked explicitly ([#2375](https://github.com/getsentry/sentry-dart/pull/2375))
- Replay: ensure visual update before capturing screenshots ([#2527](https://github.com/getsentry/sentry-dart/pull/2527))

### Dependencies

- Bump Native SDK from v0.7.15 to v0.7.17 ([#2465](https://github.com/getsentry/sentry-dart/pull/2465), [#2516](https://github.com/getsentry/sentry-dart/pull/2516))
  - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#0717)
  - [diff](https://github.com/getsentry/sentry-native/compare/0.7.15...0.7.17)
- Bump Android SDK from v7.18.1 to v7.19.0 ([#2488](https://github.com/getsentry/sentry-dart/pull/2488))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#7190)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.18.1...7.19.0)

## 8.12.0-beta.2

### Deprecations

- Manual TTID ([#2477](https://github.com/getsentry/sentry-dart/pull/2477))

### Fixes

- Missing replay gestures on Android ([#2515](https://github.com/getsentry/sentry-dart/pull/2515))
- Replay mask sizing on scaling transform widget children ([#2520](https://github.com/getsentry/sentry-dart/pull/2520))

### Enhancements

- Check `SentryTracer` type in TTFD tracker ([#2508](https://github.com/getsentry/sentry-dart/pull/2508))
- Warning (in a debug build) if a potentially sensitive widget is not masked or unmasked explicitly ([#2375](https://github.com/getsentry/sentry-dart/pull/2375))
- Replay: ensure visual update before capturing screenshots ([#2527](https://github.com/getsentry/sentry-dart/pull/2527))

### Dependencies

- Bump Native SDK from v0.7.15 to v0.7.17 ([#2465](https://github.com/getsentry/sentry-dart/pull/2465), [#2516](https://github.com/getsentry/sentry-dart/pull/2516))
  - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#0717)
  - [diff](https://github.com/getsentry/sentry-native/compare/0.7.15...0.7.17)
- Bump Android SDK from v7.18.1 to v7.19.0 ([#2488](https://github.com/getsentry/sentry-dart/pull/2488))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#7190)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.18.1...7.19.0)

## 8.11.2

### Changes

- Windows & Linux native crash handlers: add `SENTRY_NATIVE_BACKEND` env var with default setting of `none`. ([#2522](https://github.com/getsentry/sentry-dart/pull/2522))
  Native crash reporting support with `sentry-native`'s `crashpad` was added in v8.11.0 and has caused build-time issues
  for some users, because it required newer build tools (newer versions of MSVC/Clang/GCC) than base Flutter SDK.
  This broke the ability to build the app for some users compiling Windows and Linux apps with older toolchains.

  To avoid this issue, we're disabling the native crash handling by default for Linux and Windows for now.
  You can enable it manually by setting the `SENTRY_NATIVE_BACKEND=crashpad` environment variable before running `flutter build`.
  You can read more about available backends that fit your use-case in [sentry-native docs](https://docs.sentry.io/platforms/native/configuration/backends/).

  We plan to change the default back to `crashpad` in the next major SDK release.

## 8.11.1

### Improvements

- Check for type before casting in TTID ([#2497](https://github.com/getsentry/sentry-dart/pull/2497))

### Fixes

- SentryWidgetsFlutterBinding initializing even if a binding already exists ([#2494](https://github.com/getsentry/sentry-dart/pull/2494))

## 8.12.0-beta.1

### Features

- Replay: device orientation change support & improve video size fit on Android ([#2462](https://github.com/getsentry/sentry-dart/pull/2462))
- Support custom `Sentry.runZoneGuarded` zone creation ([#2088](https://github.com/getsentry/sentry-dart/pull/2088))
  - Sentry will not create a custom zone anymore if it is started within a custom one.
  - This fixes Zone miss-match errors when trying to initialize WidgetsBinding before Sentry on Flutter Web
  - `Sentry.runZonedGuarded` creates a zone and also captures exceptions & breadcrumbs automatically.
  ```dart
  Sentry.runZonedGuarded(() {
    WidgetsBinding.ensureInitialized();

    // Errors before init will not be handled by Sentry

    SentryFlutter.init(
      (options) {
      ...
      },
      appRunner: () => runApp(MyApp()),
    );
  }, (error, stackTrace) {
    // Automatically sends errors to Sentry, no need to do any
    // captureException calls on your part.
    // On top of that, you can do your own custom stuff in this callback.
  });
  ```

### Fixes

- Masking semi-transparent widgets ([#2472](https://github.com/getsentry/sentry-dart/pull/2472))

## 8.11.0

### Features

- Android 15: Add support for 16KB page sizes ([#3620](https://github.com/getsentry/sentry-java/pull/3620))
  - See https://developer.android.com/guide/practices/page-sizes for more details
- Support for screenshot PII content masking ([#2361](https://github.com/getsentry/sentry-dart/pull/2361))
  By default, masking is enabled for SessionReplay. To also enable it for screenshots captured with events, you can specify `options.experimental.privacy`:

  ```dart
  await SentryFlutter.init(
    (options) {
      ...
      // the defaults are:
      options.experimental.privacy.maskAllText = true;
      options.experimental.privacy.maskAllImages = true;
      options.experimental.privacy.maskAssetImages = false;
      // you cal also set up custom masking, for example:
      options.experimental.privacy.mask<WebView>();
    },
    appRunner: () => runApp(MyApp()),
  );
  ```

  Actually, just accessing this field will cause it to be initialized with the default settings to mask all text and images:

  ```dart
  await SentryFlutter.init(
    (options) {
      ...
      // this has a side-effect of creating the default privacy configuration, thus enabling Screenshot masking:
      options.experimental.privacy;
    },
    appRunner: () => runApp(MyApp()),
  );
  ```

- Linux native error & obfuscation support ([#2431](https://github.com/getsentry/sentry-dart/pull/2431))
- Improve Device context on plain Dart and Flutter desktop apps ([#2441](https://github.com/getsentry/sentry-dart/pull/2441))
- Add debounce to capturing screenshots ([#2368](https://github.com/getsentry/sentry-dart/pull/2368))
  - Per default, screenshots are debounced for 2 seconds.
  - If you need more granular screenshots, you can opt out of debouncing:

    ```dart
    await SentryFlutter.init((options) {
      options.beforeCaptureScreenshot = (event, hint, debounce) {
        if (debounce) {
          return true; // Capture screenshot even if the SDK wants to debounce it.
        } else {
          // check event and hint
          ...
        }
      };
    });
    ```

  - Replace deprecated `BeforeScreenshotCallback` with new `BeforeCaptureCallback`.

- Windows native error & obfuscation support ([#2286](https://github.com/getsentry/sentry-dart/pull/2286), [#2426](https://github.com/getsentry/sentry-dart/pull/2426))
- Improve app start measurements by using `addTimingsCallback` instead of `addPostFrameCallback` to determine app start end ([#2405](https://github.com/getsentry/sentry-dart/pull/2405))
  - ⚠️ This change may result in reporting of shorter app start durations
- Improve frame tracking accuracy ([#2372](https://github.com/getsentry/sentry-dart/pull/2372))
  - Introduces `SentryWidgetsFlutterBinding` that tracks a frame starting from `handleBeginFrame` and ending in `handleDrawFrame`, this is approximately the [buildDuration](https://api.flutter.dev/flutter/dart-ui/FrameTiming/buildDuration.html) time
  - By default, `SentryFlutter.init()` automatically initializes `SentryWidgetsFlutterBinding` through the `WidgetsFlutterBindingIntegration`
  - If you need to initialize the binding before `SentryFlutter.init`, use `SentryWidgetsFlutterBinding.ensureInitialized` instead of `WidgetsFlutterBinding.ensureInitialized`:

    ```dart
    void main() async {
      // Replace WidgetsFlutterBinding.ensureInitialized()
      SentryWidgetsFlutterBinding.ensureInitialized();

      await SentryFlutter.init(...);
      runApp(MyApp());
    }
    ```

  - ⚠️ Frame tracking will be disabled if a different binding is used

### Enhancements

- Only send debug images referenced in the stacktrace for events ([#2329](https://github.com/getsentry/sentry-dart/pull/2329))
- Remove `sentry` frames if SDK falls back to current stack trace ([#2351](https://github.com/getsentry/sentry-dart/pull/2351))
  - Flutter doesn't always provide stack traces for unhandled errors - this is normal Flutter behavior
  - When no stack trace is provided (in Flutter errors, `captureException`, or `captureMessage`):
    - SDK creates a synthetic trace using `StackTrace.current`
    - Internal SDK frames are removed to reduce noise
  - Original stack traces (when provided) are left unchanged

### Fixes

- Catch errors thrown during `handleBeginFrame` and `handleDrawFrame` ([#2446](https://github.com/getsentry/sentry-dart/pull/2446))
- OS & device contexts missing on Windows ([#2439](https://github.com/getsentry/sentry-dart/pull/2439))
- Native iOS/macOS SDK session didn't start after Flutter hot-restart ([#2452](https://github.com/getsentry/sentry-dart/pull/2452))
- Kotlin 2.1.0 compatibility on Android, bump Kotlin language version from `1.4` to `1.6` ([#2456](https://github.com/getsentry/sentry-dart/pull/2456))
- Apply default IP address (`{{auto}}`) to transactions ([#2395](https://github.com/getsentry/sentry-dart/pull/2395))
  - Previously, transactions weren't getting the default IP address when user context was loaded
  - Now consistently applies default IP address to both events and transactions when:
    - No user context exists
    - User context exists but IP address is null

### Dependencies

- Bump Cocoa SDK from v8.40.1 to v8.41.0 ([#2442](https://github.com/getsentry/sentry-dart/pull/2442))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8410)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.40.1...8.41.0)
- Bump Android SDK from v7.16.0 to v7.18.1 ([#2408](https://github.com/getsentry/sentry-dart/pull/2408), [#2419](https://github.com/getsentry/sentry-dart/pull/2419), [#2457](https://github.com/getsentry/sentry-dart/pull/2457))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#7181)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.16.0...7.18.1)
- Bump Native SDK from v0.7.12 to v0.7.15 ([#2430](https://github.com/getsentry/sentry-dart/pull/2430))
  - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#0715)
  - [diff](https://github.com/getsentry/sentry-native/compare/0.7.12...0.7.15)

## 8.11.0-beta.2

### Features

- Support for screenshot PII content masking ([#2361](https://github.com/getsentry/sentry-dart/pull/2361))
  By default, masking is enabled for SessionReplay. To also enable it for screenshots captured with events, you can specify `options.experimental.privacy`:
  ```dart
  await SentryFlutter.init(
    (options) {
      ...
      // the defaults are:
      options.experimental.privacy.maskAllText = true;
      options.experimental.privacy.maskAllImages = true;
      options.experimental.privacy.maskAssetImages = false;
      // you cal also set up custom masking, for example:
      options.experimental.privacy.mask<WebView>();
    },
    appRunner: () => runApp(MyApp()),
  );
  ```
  Actually, just accessing this field will cause it to be initialized with the default settings to mask all text and images:
  ```dart
  await SentryFlutter.init(
    (options) {
      ...
      // this has a side-effect of creating the default privacy configuration, thus enabling Screenshot masking:
      options.experimental.privacy;
    },
    appRunner: () => runApp(MyApp()),
  );
  ```
- Linux native error & obfuscation support ([#2431](https://github.com/getsentry/sentry-dart/pull/2431))
- Improve Device context on plain Dart and Flutter desktop apps ([#2441](https://github.com/getsentry/sentry-dart/pull/2441))
- Add debounce to capturing screenshots ([#2368](https://github.com/getsentry/sentry-dart/pull/2368))
  - Per default, screenshots are debounced for 2 seconds.
  - If you need more granular screenshots, you can opt out of debouncing:
  ```dart
  await SentryFlutter.init((options) {
    options.beforeCaptureScreenshot = (event, hint, debounce) {
      if (debounce) {
        return true; // Capture screenshot even if the SDK wants to debounce it.
      } else {
        // check event and hint
        ...
      }
    };
  });
  ```
  - Replace deprecated `BeforeScreenshotCallback` with new `BeforeCaptureCallback`.

### Fixes

- Catch errors thrown during `handleBeginFrame` and `handleDrawFrame` ([#2446](https://github.com/getsentry/sentry-dart/pull/2446))
- OS & device contexts missing on Windows ([#2439](https://github.com/getsentry/sentry-dart/pull/2439))
- Native iOS/macOS SDK session didn't start after Flutter hot-restart ([#2452](https://github.com/getsentry/sentry-dart/pull/2452))
- Kotlin 2.1.0 compatibility on Android, bump Kotlin language version from `1.4` to `1.6` ([#2456](https://github.com/getsentry/sentry-dart/pull/2456))

### Dependencies

- Bump Cocoa SDK from v8.40.1 to v8.41.0 ([#2442](https://github.com/getsentry/sentry-dart/pull/2442))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8410)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.40.1...8.41.0)
- Bump Android SDK from v7.18.0 to v7.18.1 ([#2457](https://github.com/getsentry/sentry-dart/pull/2457))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#7181)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.18.0...7.18.1)

## 8.11.0-beta.1

### Features

- Windows native error & obfuscation support ([#2286](https://github.com/getsentry/sentry-dart/pull/2286), [#2426](https://github.com/getsentry/sentry-dart/pull/2426))
- Improve app start measurements by using `addTimingsCallback` instead of `addPostFrameCallback` to determine app start end ([#2405](https://github.com/getsentry/sentry-dart/pull/2405))
  - ⚠️ This change may result in reporting of shorter app start durations
- Improve frame tracking accuracy ([#2372](https://github.com/getsentry/sentry-dart/pull/2372))
  - Introduces `SentryWidgetsFlutterBinding` that tracks a frame starting from `handleBeginFrame` and ending in `handleDrawFrame`, this is approximately the [buildDuration](https://api.flutter.dev/flutter/dart-ui/FrameTiming/buildDuration.html) time
  - By default, `SentryFlutter.init()` automatically initializes `SentryWidgetsFlutterBinding` through the `WidgetsFlutterBindingIntegration`
  - If you need to initialize the binding before `SentryFlutter.init`, use `SentryWidgetsFlutterBinding.ensureInitialized` instead of `WidgetsFlutterBinding.ensureInitialized`:
  ```dart
  void main() async {
    // Replace WidgetsFlutterBinding.ensureInitialized()
    SentryWidgetsFlutterBinding.ensureInitialized();

    await SentryFlutter.init(...);
    runApp(MyApp());
  }
  ```
  - ⚠️ Frame tracking will be disabled if a different binding is used

### Enhancements

- Only send debug images referenced in the stacktrace for events ([#2329](https://github.com/getsentry/sentry-dart/pull/2329))
- Remove `sentry` frames if SDK falls back to current stack trace ([#2351](https://github.com/getsentry/sentry-dart/pull/2351))
  - Flutter doesn't always provide stack traces for unhandled errors - this is normal Flutter behavior
  - When no stack trace is provided (in Flutter errors, `captureException`, or `captureMessage`):
    - SDK creates a synthetic trace using `StackTrace.current`
    - Internal SDK frames are removed to reduce noise
  - Original stack traces (when provided) are left unchanged

### Fixes

- Apply default IP address (`{{auto}}`) to transactions ([#2395](https://github.com/getsentry/sentry-dart/pull/2395))
  - Previously, transactions weren't getting the default IP address when user context was loaded
  - Now consistently applies default IP address to both events and transactions when:
    - No user context exists
    - User context exists but IP address is null

### Dependencies

- Bump Android SDK from v7.16.0 to v7.18.0 ([#2408](https://github.com/getsentry/sentry-dart/pull/2408), [#2419](https://github.com/getsentry/sentry-dart/pull/2419))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#7180)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.16.0...7.18.0)
- Bump Native SDK from v0.7.12 to v0.7.15 ([#2430](https://github.com/getsentry/sentry-dart/pull/2430))
  - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#0715)
  - [diff](https://github.com/getsentry/sentry-native/compare/0.7.12...0.7.15)

## 8.10.1

### Fixes

- Android build error when compiling ([#2397](https://github.com/getsentry/sentry-dart/pull/2397))

## 8.10.0

### Features

- Emit `transaction.data` inside `contexts.trace.data` ([#2284](https://github.com/getsentry/sentry-dart/pull/2284))
- Blocking app starts span if "appLaunchedInForeground" is false. (Android only) ([#2291](https://github.com/getsentry/sentry-dart/pull/2291))
- Replay: user-configurable masking (redaction) for widget classes and specific widget instances. ([#2324](https://github.com/getsentry/sentry-dart/pull/2324))
  Some examples of the configuration:

  ```dart
  await SentryFlutter.init(
    (options) {
      ...
      options.experimental.replay.mask<IconButton>();
      options.experimental.replay.unmask<Image>();
      options.experimental.replay.maskCallback<Text>(
          (Element element, Text widget) =>
              (widget.data?.contains('secret') ?? false)
                  ? SentryMaskingDecision.mask
                  : SentryMaskingDecision.continueProcessing);
    },
    appRunner: () => runApp(MyApp()),
  );
  ```

  Also, you can wrap any of your widgets with `SentryMask()` or `SentryUnmask()` widgets to mask/unmask them, respectively. For example:

  ```dart
   SentryUnmask(Text('Not secret at all'));
  ```

- Support `captureFeedback` ([#2230](https://github.com/getsentry/sentry-dart/pull/2230))
  - Deprecated `Sentry.captureUserFeedback`, use `captureFeedback` instead.
  - Deprecated `Hub.captureUserFeedback`, use `captureFeedback` instead.
  - Deprecated `SentryClient.captureUserFeedback`, use `captureFeedback` instead.
  - Deprecated `SentryUserFeedback`, use `SentryFeedback` instead.
- Add `SentryFeedbackWidget` ([#2240](https://github.com/getsentry/sentry-dart/pull/2240))

  ```dart
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SentryFeedbackWidget(associatedEventId: id),
      fullscreenDialog: true,
    ),
  );
  ```

- Add screenshot to `SentryFeedbackWidget` ([#2369](https://github.com/getsentry/sentry-dart/pull/2369))
  - Use `SentryFlutter.captureScreenshot` to create a screenshot attachment
  - Call `SentryFeedbackWidget` with this attachment to add it to the user feedback

  ```dart
  final id = await Sentry.captureMessage('UserFeedback');
  final screenshot = await SentryFlutter.captureScreenshot();

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SentryFeedbackWidget(
          associatedEventId: id,
          screenshot: screenshot,
      ),
      fullscreenDialog: true,
    ),
  );
  ```

### Enhancements

- Avoid sending too many empty client reports when Http Transport is used ([#2380](https://github.com/getsentry/sentry-dart/pull/2380))
- Cache parsed DSN ([#2365](https://github.com/getsentry/sentry-dart/pull/2365))
- Handle backpressure earlier in pipeline ([#2371](https://github.com/getsentry/sentry-dart/pull/2371))
  - Drops max un-awaited parallel tasks earlier, so event processors & callbacks are not executed for them.
  - Change by setting `SentryOptions.maxQueueSize`. Default is 30.
- Use native spotlight integrations on Flutter Android, iOS, macOS ([#2285](https://github.com/getsentry/sentry-dart/pull/2285))
- Improve app start integration ([#2266](https://github.com/getsentry/sentry-dart/pull/2266))
  - Fixes pendingTimer during tests ([#2103](https://github.com/getsentry/sentry-dart/issues/2103))
  - Fixes transaction slows app start ([#2233](https://github.com/getsentry/sentry-dart/issues/2233))
- Only store slow and frozen frames for frame delay calculation ([#2337](https://github.com/getsentry/sentry-dart/pull/2337))
- Add ReplayIntegration to the integrations list on events when replay is enabled. ([#2349](https://github.com/getsentry/sentry-dart/pull/2349))

### Fixes

- App lag with frame tracking enabled when span finishes after a long time ([#2311](https://github.com/getsentry/sentry-dart/pull/2311))
- Only start frame tracking if we receive valid display refresh data ([#2307](https://github.com/getsentry/sentry-dart/pull/2307))
- Rounding error used on frames.total and reject frame measurements if frames.total is less than frames.slow or frames.frozen ([#2308](https://github.com/getsentry/sentry-dart/pull/2308))
- iOS replay integration when only `onErrorSampleRate` is specified ([#2306](https://github.com/getsentry/sentry-dart/pull/2306))
- Fix TTID timing issue ([#2326](https://github.com/getsentry/sentry-dart/pull/2326))
- TTFD fixes
  - Start missing TTFD for root screen transaction ([#2332](https://github.com/getsentry/sentry-dart/pull/2332))
  - Match TTFD to TTID end timespan if TTFD is unfinished when user navigates to another screen ([#2347](https://github.com/getsentry/sentry-dart/pull/2347))
  - TTFD measurements should only be added for successful TTFD spans ([#2348](https://github.com/getsentry/sentry-dart/pull/2348))
  - Error when calling `SentryFlutter.reportFullyDisplayed()` twice ([#2339](https://github.com/getsentry/sentry-dart/pull/2339))
- Accessing invalid json fields from `fetchNativeAppStart` should return null ([#2340](https://github.com/getsentry/sentry-dart/pull/2340))

### Deprecate

- Metrics API ([#2312](https://github.com/getsentry/sentry-dart/pull/2312))
  - Learn more: https://sentry.zendesk.com/hc/en-us/articles/26369339769883-Metrics-Beta-Coming-to-an-End

### Dependencies

- Bump Native SDK from v0.7.10 to v0.7.12 ([#2390](https://github.com/getsentry/sentry-dart/pull/2390))
  - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#0712)
  - [diff](https://github.com/getsentry/sentry-native/compare/0.7.10...0.7.12)
- Bump Android SDK from v7.15.0 to v7.16.0 ([#2373](https://github.com/getsentry/sentry-dart/pull/2373))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#7160)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.15.0...7.16.0)
- Bump Cocoa SDK from v8.37.0 to v8.40.1 ([#2394](https://github.com/getsentry/sentry-dart/pull/2394))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8401)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.37.0...8.40.1)

## 8.10.0-beta.2

### Fixes

- Temporarily disable Windows native error & obfuscation support ([#2363](https://github.com/getsentry/sentry-dart/pull/2363))

## 8.10.0-beta.1

### Features

- Emit `transaction.data` inside `contexts.trace.data` ([#2284](https://github.com/getsentry/sentry-dart/pull/2284))
- Blocking app starts if "appLaunchedInForeground" is false. (Android only) ([#2291](https://github.com/getsentry/sentry-dart/pull/2291))
- Windows native error & obfuscation support ([#2286](https://github.com/getsentry/sentry-dart/pull/2286))
- Replay: user-configurable masking (redaction) for widget classes and specific widget instances. ([#2324](https://github.com/getsentry/sentry-dart/pull/2324))
  Some examples of the configuration:

  ```dart
  await SentryFlutter.init(
    (options) {
      ...
      options.experimental.replay.mask<IconButton>();
      options.experimental.replay.unmask<Image>();
      options.experimental.replay.maskCallback<Text>(
          (Element element, Text widget) =>
              (widget.data?.contains('secret') ?? false)
                  ? SentryMaskingDecision.mask
                  : SentryMaskingDecision.continueProcessing);
    },
    appRunner: () => runApp(MyApp()),
  );
  ```

  Also, you can wrap any of your widgets with `SentryMask()` or `SentryUnmask()` widgets to mask/unmask them, respectively. For example:

  ```dart
   SentryUnmask(Text('Not secret at all'));
  ```

- Support `captureFeedback` ([#2230](https://github.com/getsentry/sentry-dart/pull/2230))
  - Deprecated `Sentry.captureUserFeedback`, use `captureFeedback` instead.
  - Deprecated `Hub.captureUserFeedback`, use `captureFeedback` instead.
  - Deprecated `SentryClient.captureUserFeedback`, use `captureFeedback` instead.
  - Deprecated `SentryUserFeedback`, use `SentryFeedback` instead.
- Add `SentryFeedbackWidget` ([#2240](https://github.com/getsentry/sentry-dart/pull/2240))

  ```dart
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SentryFeedbackWidget(associatedEventId: id),
      fullscreenDialog: true,
    ),
  );
  ```

### Enhancements

- Use native spotlight integrations on Flutter Android, iOS, macOS ([#2285](https://github.com/getsentry/sentry-dart/pull/2285))
- Improve app start integration ([#2266](https://github.com/getsentry/sentry-dart/pull/2266))
  - Fixes ([#2103](https://github.com/getsentry/sentry-dart/issues/2103))
  - Fixes ([#2233](https://github.com/getsentry/sentry-dart/issues/2233))
- Only store slow and frozen frames for frame delay calculation ([#2337](https://github.com/getsentry/sentry-dart/pull/2337))
- Add ReplayIntegration to the integrations list on events when replay is enabled. ([#2349](https://github.com/getsentry/sentry-dart/pull/2349))

### Fixes

- App lag with frame tracking enabled when span finishes after a long time ([#2311](https://github.com/getsentry/sentry-dart/pull/2311))
- Only start frame tracking if we receive valid display refresh data ([#2307](https://github.com/getsentry/sentry-dart/pull/2307))
- Rounding error used on frames.total and reject frame measurements if frames.total is less than frames.slow or frames.frozen ([#2308](https://github.com/getsentry/sentry-dart/pull/2308))
- iOS replay integration when only `onErrorSampleRate` is specified ([#2306](https://github.com/getsentry/sentry-dart/pull/2306))
- Fix TTID timing issue ([#2326](https://github.com/getsentry/sentry-dart/pull/2326))
- Start missing TTFD for root screen transaction ([#2332](https://github.com/getsentry/sentry-dart/pull/2332))
- Match TTFD to TTID end timespan if TTFD is unfinished when user navigates to another screen ([#2347](https://github.com/getsentry/sentry-dart/pull/2347))
- Accessing invalid json fields from `fetchNativeAppStart` should return null ([#2340](https://github.com/getsentry/sentry-dart/pull/2340))
- Error when calling `SentryFlutter.reportFullyDisplayed()` twice ([#2339](https://github.com/getsentry/sentry-dart/pull/2339))
- TTFD measurements should only be added for successful TTFD spans ([#2348](https://github.com/getsentry/sentry-dart/pull/2348))

### Deprecate

- Metrics API ([#2312](https://github.com/getsentry/sentry-dart/pull/2312))
  - Learn more: https://sentry.zendesk.com/hc/en-us/articles/26369339769883-Metrics-Beta-Coming-to-an-End

### Dependencies

- Bump Cocoa SDK from v8.36.0 to v8.37.0 ([#2334](https://github.com/getsentry/sentry-dart/pull/2334))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8370)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.36.0...8.37.0)
- Bump Android SDK from v7.14.0 to v7.15.0 ([#2342](https://github.com/getsentry/sentry-dart/pull/2342))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#7150)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.14.0...7.15.0)
- Bump Native SDK from v0.7.8 to v0.7.10 ([#2344](https://github.com/getsentry/sentry-dart/pull/2344))
  - [changelog](https://github.com/getsentry/sentry-native/blob/master/CHANGELOG.md#0710)
  - [diff](https://github.com/getsentry/sentry-native/compare/0.7.8...0.7.10)

## 8.9.0

### Features

- Session replay Alpha for Android and iOS ([#2208](https://github.com/getsentry/sentry-dart/pull/2208), [#2269](https://github.com/getsentry/sentry-dart/pull/2269), [#2236](https://github.com/getsentry/sentry-dart/pull/2236), [#2275](https://github.com/getsentry/sentry-dart/pull/2275), [#2270](https://github.com/getsentry/sentry-dart/pull/2270)).
  To try out replay, you can set following options (access is limited to early access orgs on Sentry. If you're interested, [sign up for the waitlist](https://sentry.io/lp/mobile-replay-beta/)):

  ```dart
  await SentryFlutter.init(
    (options) {
      ...
      options.experimental.replay.sessionSampleRate = 1.0;
      options.experimental.replay.onErrorSampleRate = 1.0;
    },
    appRunner: () => runApp(MyApp()),
  );
  ```

- Support allowUrls and denyUrls for Flutter Web ([#2227](https://github.com/getsentry/sentry-dart/pull/2227))
  ```dart
  await SentryFlutter.init(
    (options) {
      ...
      options.allowUrls = ["^https://sentry.com.*\$", "my-custom-domain"];
      options.denyUrls = ["^.*ends-with-this\$", "denied-url"];
    },
    appRunner: () => runApp(MyApp()),
  );
  ```
- Collect touch breadcrumbs for all buttons, not just those with `key` specified. ([#2242](https://github.com/getsentry/sentry-dart/pull/2242))
- Add `enableDartSymbolication` option to Sentry.init() for **Flutter iOS, macOS and Android** ([#2256](https://github.com/getsentry/sentry-dart/pull/2256))
  - This flag enables symbolication of Dart stack traces when native debug images are not available.
  - Useful when using Sentry.init() instead of SentryFlutter.init() in Flutter projects for example due to size limitations.
  - `true` by default but automatically set to `false` when using SentryFlutter.init() because the SentryFlutter fetches debug images from the native SDK integrations.

### Dependencies

- Bump Cocoa SDK from v8.35.1 to v8.36.0 ([#2252](https://github.com/getsentry/sentry-dart/pull/2252))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8360)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.35.1...8.36.0)

### Fixes

- Only access renderObject if `hasSize` is true ([#2263](https://github.com/getsentry/sentry-dart/pull/2263))

## 8.8.0

### Features

- Add `SentryFlutter.nativeCrash()` using MethodChannels for Android and iOS ([#2239](https://github.com/getsentry/sentry-dart/pull/2239))
  - This can be used to test if native crash reporting works
- Add `ignoreRoutes` parameter to `SentryNavigatorObserver`. ([#2218](https://github.com/getsentry/sentry-dart/pull/2218))
    - This will ignore the Routes and prevent the Route from being pushed to the Sentry server.
    - Ignored routes will also create no TTID and TTFD spans.
```dart
SentryNavigatorObserver(ignoreRoutes: ["/ignoreThisRoute"]),
```

### Improvements

- Debouncing of SentryWidgetsBindingObserver.didChangeMetrics with delay of 100ms. ([#2232](https://github.com/getsentry/sentry-dart/pull/2232))

### Dependencies

- Bump Cocoa SDK from v8.33.0 to v8.35.1 ([#2247](https://github.com/getsentry/sentry-dart/pull/2247))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8351)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.33.0...8.35.1)
- Bump Android SDK from v7.13.0 to v7.14.0 ([#2228](https://github.com/getsentry/sentry-dart/pull/2228))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#7140)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.13.0...7.14.0)

## 8.8.0-alpha.1

### Features

- iOS Session Replay Alpha ([#2209](https://github.com/getsentry/sentry-dart/pull/2209))
- Android replay touch tracking support ([#2228](https://github.com/getsentry/sentry-dart/pull/2228))
- Add `ignoreRoutes` parameter to `SentryNavigatorObserver`. ([#2218](https://github.com/getsentry/sentry-dart/pull/2218))
  - This will ignore the Routes and prevent the Route from being pushed to the Sentry server.
  - Ignored routes will also create no TTID and TTFD spans.

```dart
SentryNavigatorObserver(ignoreRoutes: ["/ignoreThisRoute"]),
```

### Dependencies

- Bump Android SDK from v7.13.0 to v7.14.0 ([#2228](https://github.com/getsentry/sentry-dart/pull/2228))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#7140)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.13.0...7.14.0)

## 8.7.0

### Features

- Add support for span level measurements. ([#2214](https://github.com/getsentry/sentry-dart/pull/2214))
- Add `ignoreTransactions` and `ignoreErrors` to options ([#2207](https://github.com/getsentry/sentry-dart/pull/2207))

  ```dart
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://examplePublicKey@o0.ingest.sentry.io/0';
      options.ignoreErrors = ["my-error", "^error-.*\$"];
      options.ignoreTransactions = ["my-transaction", "^transaction-.*\$"];
      ...
    },
    appRunner: () => runApp(MyApp()),
  );
  ```

- Add proxy support ([#2192](https://github.com/getsentry/sentry-dart/pull/2192))
  - Configure a `SentryProxy` object and set it on `SentryFlutter.init`

  ```dart
  import 'package:flutter/widgets.dart';
  import 'package:sentry_flutter/sentry_flutter.dart';

  Future<void> main() async {
    await SentryFlutter.init(
      (options) {
        options.dsn = 'https://example@sentry.io/add-your-dsn-here';
        options.proxy = SentryProxy(
          type: SentryProxyType.http,
          host: 'localhost',
          port: 8080,
        );
      },
      // Init your App.
      appRunner: () => runApp(MyApp()),
    );
  }
  ```

### Improvements

- Deserialize and serialize unknown fields ([#2153](https://github.com/getsentry/sentry-dart/pull/2153))

### Dependencies

- Bump Cocoa SDK from v8.32.0 to v8.33.0 ([#2223](https://github.com/getsentry/sentry-dart/pull/2223))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8330)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.32.0...8.33.0)

## 8.6.0

### Improvements

- Add error type identifier to improve obfuscated Flutter issue titles ([#2170](https://github.com/getsentry/sentry-dart/pull/2170))
  - Example: transforms issue titles from `GA` to `FlutterError` or `minified:nE` to `FlutterError`
  - This is enabled automatically and will change grouping if you already have issues with obfuscated titles
  - If you want to disable this feature, set `enableExceptionTypeIdentification` to `false` in your Sentry options
  - You can add your custom exception identifier if there are exceptions that we do not identify out of the box

  ```dart
  // How to add your own custom exception identifier
  class MyCustomExceptionIdentifier implements ExceptionIdentifier {
    @override
    String? identifyType(Exception exception) {
      if (exception is MyCustomException) {
        return 'MyCustomException';
      }
      if (exception is MyOtherCustomException) {
        return 'MyOtherCustomException';
      }
      return null;
    }
  }

  SentryFlutter.init((options) =>
    options..prependExceptionTypeIdentifier(MyCustomExceptionIdentifier()));
  ```

### Deprecated

- Deprecate `enableTracing` ([#2199](https://github.com/getsentry/sentry-dart/pull/2199))
  - The `enableTracing` option has been deprecated and will be removed in the next major version. We recommend removing it
    in favor of the `tracesSampleRate` and `tracesSampler` options. If you want to enable performance monitoring, please set
    the `tracesSampleRate` to a sample rate of your choice, or provide a sampling function as `tracesSampler` option
    instead. If you want to disable performance monitoring, remove the `tracesSampler` and `tracesSampleRate` options.

### Dependencies

- Bump Android SDK from v7.12.0 to v7.13.0 ([#2198](https://github.com/getsentry/sentry-dart/pull/2198), [#2206](https://github.com/getsentry/sentry-dart/pull/2206))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#7130)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.12.0...7.13.0)

## 8.6.0-alpha.2

### Features

- Android Session Replay Alpha ([#2032](https://github.com/getsentry/sentry-dart/pull/2032))

  To try out replay, you can set following options:

  ```dart
  await SentryFlutter.init(
    (options) {
      ...
      options.experimental.replay.sessionSampleRate = 1.0;
      options.experimental.replay.onErrorSampleRate = 1.0;
    },
    appRunner: () => runApp(MyApp()),
  );
  ```

  Access is limited to early access orgs on Sentry. If you're interested, [sign up for the waitlist](https://sentry.io/lp/mobile-replay-beta/)

## 8.5.0

### Features

- Add dart platform to sentry frames ([#2193](https://github.com/getsentry/sentry-dart/pull/2193))
  - This allows viewing the correct dart formatted raw stacktrace in the Sentry UI
- Support `ignoredExceptionsForType` ([#2150](https://github.com/getsentry/sentry-dart/pull/2150))
  - Filter out exception types by calling `SentryOptions.addExceptionFilterForType(Type exceptionType)`

### Fixes

- Disable sff & frame delay detection on web, linux and windows ([#2182](https://github.com/getsentry/sentry-dart/pull/2182))
  - Display refresh rate is locked at 60 for these platforms which can lead to inaccurate metrics

### Improvements

- Capture meaningful stack traces when unhandled errors have empty or missing stack traces ([#2152](https://github.com/getsentry/sentry-dart/pull/2152))
  - This will affect grouping for unhandled errors that have empty or missing stack traces.

### Dependencies

- Bump Android SDK from v7.11.0 to v7.12.0 ([#2173](https://github.com/getsentry/sentry-dart/pull/2173))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#7120)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.11.0...7.12.0)
  - updates AGP to v7.4.2
  - updates Kotlin to v1.8.0
- Bump Cocoa SDK from v8.30.1 to v8.32.0 ([#2174](https://github.com/getsentry/sentry-dart/pull/2174), [#2195](https://github.com/getsentry/sentry-dart/pull/2195))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8320)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.30.1...8.32.0)

## 8.4.0

### Features

- Add API for pausing/resuming **iOS** and **macOS** app hang tracking ([#2134](https://github.com/getsentry/sentry-dart/pull/2134))
  - This is useful to prevent the Cocoa SDK from reporting wrongly detected app hangs when the OS shows a system dialog for asking specific permissions.
  - Use `SentryFlutter.pauseAppHangTracking()` and `SentryFlutter.resumeAppHangTracking()`
- Capture total frames, frames delay, slow & frozen frames and attach to spans ([#2106](https://github.com/getsentry/sentry-dart/pull/2106))
- Support WebAssembly compilation (dart2wasm) ([#2113](https://github.com/getsentry/sentry-dart/pull/2113))
- Add flag to disable reporting of view hierarchy identifiers ([#2158](https://github.com/getsentry/sentry-dart/pull/2158))
  - Use `reportViewHierarchyIdentifiers` to enable or disable the option
- Record dropped spans in client reports ([#2154](https://github.com/getsentry/sentry-dart/pull/2154))
- Add memory usage to contexts ([#2133](https://github.com/getsentry/sentry-dart/pull/2133))
  - Only for Linux/Windows applications, as iOS/Android/macOS use native SDKs

### Fixes

- Fix sentry_drift compatibility with Drift 2.19.0 ([#2162](https://github.com/getsentry/sentry-dart/pull/2162))
- App starts hanging for 30s ([#2140](https://github.com/getsentry/sentry-dart/pull/2140))
  - Time out for app start info retrieval has been reduced to 10s
  - If `autoAppStarts` is `false` and `setAppStartEnd` has not been called, the app start event processor will now return early instead of waiting for `getAppStartInfo` to finish

### Improvements

- Set dart runtime version with parsed `Platform.version` ([#2156](https://github.com/getsentry/sentry-dart/pull/2156))

### Dependencies

- Bump Cocoa SDK from v8.30.0 to v8.30.1 ([#2155](https://github.com/getsentry/sentry-dart/pull/2155))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8301)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.30.0...8.30.1)
- Bump Android SDK from v7.10.0 to v7.11.0 ([#2144](https://github.com/getsentry/sentry-dart/pull/2144))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#7110)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.10.0...7.11.0)

### Deprecated

- User segment is now deprecated and will be removed in version 9.0.0. Use a custom tag or context instead. ([#2119](https://github.com/getsentry/sentry-dart/pull/2119))
- Deprecate `setExtra` and `removeExtra` ([#2159](https://github.com/getsentry/sentry-dart/pull/2159))
  - Use the `Contexts` structure via `setContexts` instead

## 8.4.0-beta.1

### Features

- Add API for pausing/resuming **iOS** and **macOS** app hang tracking ([#2134](https://github.com/getsentry/sentry-dart/pull/2134))
  - This is useful to prevent the Cocoa SDK from reporting wrongly detected app hangs when the OS shows a system dialog for asking specific permissions.
  - Use `SentryFlutter.pauseAppHangTracking()` and `SentryFlutter.resumeAppHangTracking()`
- Capture total frames, frames delay, slow & frozen frames and attach to spans ([#2106](https://github.com/getsentry/sentry-dart/pull/2106))
- Support WebAssembly compilation (dart2wasm) ([#2113](https://github.com/getsentry/sentry-dart/pull/2113))

### Deprecated

- User segment is now deprecated and will be removed in version 9.0.0. Use a custom tag or context instead. ([#2119](https://github.com/getsentry/sentry-dart/pull/2119))

### Dependencies

- Bump Cocoa SDK from v8.29.0 to v8.30.0 ([#2132](https://github.com/getsentry/sentry-dart/pull/2132))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8300)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.29.0...8.30.0)

## 8.3.0

### Fixes

- Load contexts integration not setting `SentryUser` ([#2089](https://github.com/getsentry/sentry-dart/pull/2089))
- Change app start span description from `Cold start` to `Cold Start` and `Warm start` to `Warm Start` ([#2076](https://github.com/getsentry/sentry-dart/pull/2076))
- Parse `PlatformException` from details instead of message ([#2052](https://github.com/getsentry/sentry-dart/pull/2052))

### Dependencies

- Bump `sqflite` minimum version from `^2.0.0` to `^2.2.8` ([#2075](https://github.com/getsentry/sentry-dart/pull/2075))
  - This is not a breaking change since we are using api internally that is only valid from that version.
- Bump Cocoa SDK from v8.25.2 to v8.29.0 ([#2060](https://github.com/getsentry/sentry-dart/pull/2060), [#2092](https://github.com/getsentry/sentry-dart/pull/2092), [#2100](https://github.com/getsentry/sentry-dart/pull/2100))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8290)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.25.2...8.29.0)
- Bump Android SDK from v7.9.0 to v7.10.0 ([#2090](https://github.com/getsentry/sentry-dart/pull/2090))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#7100)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.9.0...7.10.0)

## 8.2.0

### Enhancements

- Include sentry frames in stacktraces to enable SDK crash detection ([#2050](https://github.com/getsentry/sentry-dart/pull/2050))

### Fixes

- Event processor blocking transactions from being sent if `autoAppStart` is false ([#2028](https://github.com/getsentry/sentry-dart/pull/2028))

### Features

- Create app start transaction when no `SentryNavigatorObserver` is present ([#2017](https://github.com/getsentry/sentry-dart/pull/2017))
- Adds native spans to app start transaction ([#2027](https://github.com/getsentry/sentry-dart/pull/2027))
- Adds app start spans to first transaction ([#2009](https://github.com/getsentry/sentry-dart/pull/2009))

### Fixes

- Fix `PlatformException` title parsing ([#2033](https://github.com/getsentry/sentry-dart/pull/2033))

### Dependencies

- Bump Cocoa SDK from v8.25.0 to v8.25.2 ([#2042](https://github.com/getsentry/sentry-dart/pull/2042))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8252)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.25.0...8.25.2)
- Bump Android SDK from v7.8.0 to v7.9.0 ([#2049](https://github.com/getsentry/sentry-dart/pull/2049))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#790)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.8.0...7.9.0)

## 8.1.0

### Features

- Set snapshot to `true` if stacktrace is not provided ([#2000](https://github.com/getsentry/sentry-dart/pull/2000))
  - If the stacktrace is not provided, the Sentry SDK will fetch the current stacktrace via `StackTrace.current` and the snapshot will be set to `true` - **this may change the grouping behavior**
  - `snapshot = true` means it's a synthetic exception, reflecting the current state of the thread rather than the stack trace of a real exception

### Fixes

- Timing metric aggregates metrics in the created span ([#1994](https://github.com/getsentry/sentry-dart/pull/1994))

### Dependencies

- Bump Cocoa SDK from v8.21.0 to v8.25.0 ([#2018](https://github.com/getsentry/sentry-dart/pull/2018))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8250)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.21.0...8.25.0)
- Expand dependency range of `package_info_plus` to allow an open range starting from version 1 ([#2010](https://github.com/getsentry/sentry-dart/pull/2010))

## 8.0.0

This release contains breaking changes, please read the changelog carefully.

*Changes from the latest v7 release are included in this major release*

### Breaking Changes

- Bump iOS minimum deployment target from **11** to **12** ([#1821](https://github.com/getsentry/sentry-dart/pull/1821))
- Mark exceptions not handled by the user as `handled: false` ([#1535](https://github.com/getsentry/sentry-dart/pull/1535))
  - This will affect your release health data, and is therefore considered a breaking change.
- Refrain from overwriting the span status for unfinished spans ([#1577](https://github.com/getsentry/sentry-dart/pull/1577))
  - Older self-hosted sentry instances will drop transactions containing unfinished spans.
    - This change was introduced in [relay/#1690](https://github.com/getsentry/relay/pull/1690) and released with [22.12.0](https://github.com/getsentry/relay/releases/tag/22.12.0)
- Do not leak extensions of external classes ([#1576](https://github.com/getsentry/sentry-dart/pull/1576))
- Make `hint` non-nullable in `BeforeSendCallback`, `BeforeBreadcrumbCall` and `EventProcessor` ([#1574](https://github.com/getsentry/sentry-dart/pull/1574))
  - This will affect your callbacks, making this a breaking change.
- Load Device Contexts from Sentry Java ([#1616](https://github.com/getsentry/sentry-dart/pull/1616))
  - Now the device context from Android is available in `BeforeSendCallback`
- Set ip_address to {{auto}} by default, even if sendDefaultPII is disabled ([#1665](https://github.com/getsentry/sentry-dart/pull/1665))
  - Instead use the "Prevent Storing of IP Addresses" option in the "Security & Privacy" project settings on sentry.io

### Features

- Add support for exception aggregates ([#1866](https://github.com/getsentry/sentry-dart/pull/1866))

## 7.20.0

### Build

- Bump compileSdkVersion to 34 in Gradle buildscripts ([#1980](https://github.com/getsentry/sentry-dart/pull/1980))

### Features

- Add textScale(r) value to Flutter context ([#1886](https://github.com/getsentry/sentry-dart/pull/1886))

### Dependencies

- Expand dependency range of `package_info_plus` to include major version 7 ([#1984](https://github.com/getsentry/sentry-dart/pull/1984))
- Bump Android SDK from v7.6.0 to v7.8.0 ([#1977](https://github.com/getsentry/sentry-dart/pull/1977))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#780)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.6.0...7.8.0)

## 7.19.0

### Features

- Experimental: Add support for Sentry Developer Metrics ([#1940](https://github.com/getsentry/sentry-dart/pull/1940), [#1949](https://github.com/getsentry/sentry-dart/pull/1949), [#1954](https://github.com/getsentry/sentry-dart/pull/1954), [#1958](https://github.com/getsentry/sentry-dart/pull/1958))
  Use the Metrics API to track processing time, download sizes, user signups, and conversion rates and correlate them back to tracing data in order to get deeper insights and solve issues faster. Our API supports counters, distributions, sets, gauges and timers, and it's easy to get started:
  ```dart
  Sentry.metrics()
      .increment(
      'button_login_click', // key
      value: 1.0,
      unit: null,
      tags: {"provider": "e-mail"}
  );
  ```
  To learn more about Sentry Developer Metrics, head over to our [Dart](https://docs.sentry.io/platforms/dart/metrics/) and [Flutter](https://docs.sentry.io/platforms/flutter/metrics/) docs page.

### Dependencies

- Expand `package_info_plus` version range to `6.0.0` ([#1948](https://github.com/getsentry/sentry-dart/pull/1948))

### Improvements

- Set `sentry_flutter.podspec` version from `pubspec.yaml` ([#1941](https://github.com/getsentry/sentry-dart/pull/1941))

## 7.18.0

### Features

- Add TTFD (time to full display), which allows you to measure the time it takes to render the full screen ([#1920](https://github.com/getsentry/sentry-dart/pull/1920))
  - Requires using the [routing instrumentation](https://docs.sentry.io/platforms/flutter/integrations/routing-instrumentation/).
  - Set `enableTimeToFullDisplayTracing = true` in your `SentryFlutterOptions` to enable TTFD
  - Manually report the end of the full display by calling `SentryFlutter.reportFullyDisplayed()`
  - If not reported within 30 seconds, the span will be automatically finish with the status `deadline_exceeded`
- Add TTID (time to initial display), which allows you to measure the time it takes to render the first frame of your screen ([#1910](https://github.com/getsentry/sentry-dart/pull/1910))
  - Requires using the [routing instrumentation](https://docs.sentry.io/platforms/flutter/integrations/routing-instrumentation/).
  - Introduces two modes:
    - `automatic` mode is enabled by default for all screens and will yield only an approximation result.
    - `manual` mode requires manual instrumentation and will yield a more accurate result.
      - To use `manual` mode, you need to wrap your desired widget: `SentryDisplayWidget(child: MyScreen())`.
    - You can mix and match both modes in your app.
  - Other significant fixes
    - `didPop` doesn't trigger a new transaction
    - Change transaction operation name to `ui.load` instead of `navigation`
- Add override `captureFailedRequests` option ([#1931](https://github.com/getsentry/sentry-dart/pull/1931))
  - The `dio` integration and `SentryHttpClient` now take an additional `captureFailedRequests` option.
  - This is useful if you want to disable this option on native and only enable it on `dio` for example.

### Improvements

- Update root name for navigator observer ([#1934](https://github.com/getsentry/sentry-dart/pull/1934))
  - The root name for transactions is now `root /` instead of `root ("/")`.

### Dependencies

- Bump Android SDK from v7.5.0 to v7.6.0 ([#1927](https://github.com/getsentry/sentry-dart/pull/1927))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#760)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.5.0...7.6.0)

## 7.17.0

### Fixes

- Fix transaction end timestamp trimming ([#1916](https://github.com/getsentry/sentry-dart/pull/1916))
  - Transaction end timestamps are now correctly trimmed to the latest child span end timestamp
- remove transitive dart:io reference for web ([#1898](https://github.com/getsentry/sentry-dart/pull/1898))

### Features

- Use `recordHttpBreadcrumbs` to set iOS `enableNetworkBreadcrumbs` ([#1884](https://github.com/getsentry/sentry-dart/pull/1884))
- Apply `beforeBreadcrumb` on native iOS crumbs ([#1914](https://github.com/getsentry/sentry-dart/pull/1914))
- Add `maxQueueSize` to limit the number of unawaited events sent to Sentry ([#1868](https://github.com/getsentry/sentry-dart/pull/1868))

### Improvements

- App start is now fetched within integration instead of event processor ([#1905](https://github.com/getsentry/sentry-dart/pull/1905))

### Dependencies

- Bump Cocoa SDK from v8.20.0 to v8.21.0 ([#1909](https://github.com/getsentry/sentry-dart/pull/1909))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8210)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.20.0...8.21.0)
- Bump Android SDK from v7.3.0 to v7.5.0 ([#1907](https://github.com/getsentry/sentry-dart/pull/1907))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#750)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.3.0...7.5.0)

## 7.16.1

### Fixes

- Remove Flutter dependency from Drift integration ([#1867](https://github.com/getsentry/sentry-dart/pull/1867))
- Remove dead code, cold start bool is now always present ([#1861](https://github.com/getsentry/sentry-dart/pull/1861))
- Fix iOS "Arithmetic Overflow" ([#1874](https://github.com/getsentry/sentry-dart/pull/1874))

### Dependencies

- Bump Cocoa SDK from v8.19.0 to v8.20.0 ([#1856](https://github.com/getsentry/sentry-dart/pull/1856))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8200)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.19.0...8.20.0)

## 8.0.0-beta.2

### Breaking Changes

- Bump iOS minimum deployment target from **11** to **12** ([#1821](https://github.com/getsentry/sentry-dart/pull/1821))
- Mark exceptions not handled by the user as `handled: false` ([#1535](https://github.com/getsentry/sentry-dart/pull/1535))
  - This will affect your release health data, and is therefore considered a breaking change.
- Refrain from overwriting the span status for unfinished spans ([#1577](https://github.com/getsentry/sentry-dart/pull/1577))
  - Older self-hosted sentry instances will drop transactions containing unfinished spans.
    - This change was introduced in [relay/#1690](https://github.com/getsentry/relay/pull/1690) and released with [22.12.0](https://github.com/getsentry/relay/releases/tag/22.12.0)
- Do not leak extensions of external classes ([#1576](https://github.com/getsentry/sentry-dart/pull/1576))
- Make `hint` non-nullable in `BeforeSendCallback`, `BeforeBreadcrumbCall` and `EventProcessor` ([#1574](https://github.com/getsentry/sentry-dart/pull/1574))
  - This will affect your callbacks, making this a breaking change.
- Load Device Contexts from Sentry Java ([#1616](https://github.com/getsentry/sentry-dart/pull/1616))
  - Now the device context from Android is available in `BeforeSendCallback`
- Set ip_address to {{auto}} by default, even if sendDefaultPII is disabled ([#1665](https://github.com/getsentry/sentry-dart/pull/1665))
  - Instead use the "Prevent Storing of IP Addresses" option in the "Security & Privacy" project settings on sentry.io

### Fixes

- Remove Flutter dependency from Drift integration ([#1867](https://github.com/getsentry/sentry-dart/pull/1867))
- Remove dead code, cold start bool is now always present ([#1861](https://github.com/getsentry/sentry-dart/pull/1861))
- Fix iOS "Arithmetic Overflow" ([#1874](https://github.com/getsentry/sentry-dart/pull/1874))

### Dependencies

- Bump Cocoa SDK from v8.19.0 to v8.20.0 ([#1856](https://github.com/getsentry/sentry-dart/pull/1856))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8200)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.19.0...8.20.0)

## 8.0.0-beta.1

This release is replaced by `8.0.0-beta.2`

## 7.16.0

### Features

- Add `SentryWidget` ([#1846](https://github.com/getsentry/sentry-dart/pull/1846))
  - Prefer to use `SentryWidget` now instead of `SentryScreenshotWidget` and `SentryUserInteractionWidget` directly
- Performance monitoring support for Isar ([#1726](https://github.com/getsentry/sentry-dart/pull/1726))
- Tracing without performance for Dio integration ([#1837](https://github.com/getsentry/sentry-dart/pull/1837))
- Accept `Map<String, dynamic>` in `Hint` class ([#1807](https://github.com/getsentry/sentry-dart/pull/1807))
  - Please check if everything works as expected when using `Hint`
    - Factory constructor `Hint.withMap(Map<String, dynamic> map)` now takes `Map<String, dynamic>` instead of `Map<String, Object>`
    - Method `hint.addAll(Map<String, dynamic> keysAndValues)` now takes `Map<String, dynamic>` instead of `Map<String, Object>`
    - Method `set(String key, dynamic value)` now takes value of `dynamic` instead of `Object`
    - Method `hint.get(String key)` now returns `dynamic` instead of `Object?`

### Dependencies

- Bump Cocoa SDK from v8.18.0 to v8.19.0 ([#1803](https://github.com/getsentry/sentry-dart/pull/1844))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8190)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.18.0...8.19.0)
- Bump Android SDK from v7.2.0 to v7.3.0 ([#1852](https://github.com/getsentry/sentry-dart/pull/1852))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#730)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.2.0...7.3.0)

## 7.15.0

### Features

- Add [Spotlight](https://spotlightjs.com/about/) support ([#1786](https://github.com/getsentry/sentry-dart/pull/1786))
  - Set `options.spotlight = Spotlight(enabled: true)` to enable Spotlight
- Add `ConnectivityIntegration` for web ([#1765](https://github.com/getsentry/sentry-dart/pull/1765))
  - We only get the info if online/offline on web platform. The added breadcrumb is set to either `wifi` or `none`.
- Add isar breadcrumbs ([#1800](https://github.com/getsentry/sentry-dart/pull/1800))
- Starting with Flutter 3.16, Sentry adds the [`appFlavor`](https://api.flutter.dev/flutter/services/appFlavor-constant.html) to the `flutter_context` ([#1799](https://github.com/getsentry/sentry-dart/pull/1799))
- Add beforeScreenshotCallback to SentryFlutterOptions ([#1805](https://github.com/getsentry/sentry-dart/pull/1805))
- Add support for `readTransaction` in `sqflite` ([#1819](https://github.com/getsentry/sentry-dart/pull/1819))

### Dependencies

- Bump Android SDK from v7.0.0 to v7.2.0 ([#1788](https://github.com/getsentry/sentry-dart/pull/1788), [#1815](https://github.com/getsentry/sentry-dart/pull/1815))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#720)
  - [diff](https://github.com/getsentry/sentry-java/compare/7.0.0...7.2.0)
- Bump Cocoa SDK from v8.17.2 to v8.18.0 ([#1803](https://github.com/getsentry/sentry-dart/pull/1803))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8180)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.17.2...8.18.0)

## 7.14.0

- Add option to opt out of fatal level for automatically collected errors ([#1738](https://github.com/getsentry/sentry-dart/pull/1738))

### Fixes

- Add debug_meta to all events ([#1756](https://github.com/getsentry/sentry-dart/pull/1756))
  - Fixes obfuscated stacktraces when `captureMessage` or `captureEvent` is called with `attachStacktrace` option

### Features

- Add option to opt out of fatal level for automatically collected errors ([#1738](https://github.com/getsentry/sentry-dart/pull/1738))
- Add `Hive` breadcrumbs ([#1773](https://github.com/getsentry/sentry-dart/pull/1773))

### Dependencies

- Bump Android SDK from v6.34.0 to v7.0.0 ([#1768](https://github.com/getsentry/sentry-dart/pull/1768))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#700)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.34.0...7.0.0)
- Bump Cocoa SDK from v8.15.2 to v8.17.2 ([#1761](https://github.com/getsentry/sentry-dart/pull/1761), [#1771](https://github.com/getsentry/sentry-dart/pull/1771), [#1787](https://github.com/getsentry/sentry-dart/pull/1787))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8172)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.15.2...8.17.2)

## 7.13.2

### Fixes

- Fix SIGSEV, SIGABRT and SIGBUS crashes happening after/around the August Google Play System update, see [#2955](https://github-redirect.dependabot.com/getsentry/sentry-java/issues/2955) for more details (fix provided by Native SDK bump)

### Dependencies

- Update package-info-plus constraint to include 5.0.1 ([#1749](https://github.com/getsentry/sentry-dart/pull/1749))
- Bump Android SDK from v6.33.1 to v6.34.0 ([#1746](https://github.com/getsentry/sentry-dart/pull/1746))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#6340)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.33.1...6.34.0)

## 7.13.1

### Fixes

- Fixes release of drift & hive and adds missing integration & sdk version information in the hub options ([#1729](https://github.com/getsentry/sentry-dart/pull/1729))

## 7.13.0

### Fixes

- Fixes setting the correct locale to contexts with navigatorKey ([#1724](https://github.com/getsentry/sentry-dart/pull/1724))
  - If you have a selected locale in e.g MaterialApp, this fix will retrieve the correct locale for the event context.
- Flutter renderer information was removed on dart:io platforms since it didn't add the correct value ([#1723](https://github.com/getsentry/sentry-dart/pull/1723))
- Unsupported types with Expando ([#1690](https://github.com/getsentry/sentry-dart/pull/1690))

### Features

- Add APM integration for Drift ([#1709](https://github.com/getsentry/sentry-dart/pull/1709))
- StackTraces in `PlatformException.message` will get nicely formatted too when present ([#1716](https://github.com/getsentry/sentry-dart/pull/1716))
- Breadcrumbs for database operations ([#1656](https://github.com/getsentry/sentry-dart/pull/1656))
- APM for hive ([#1672](https://github.com/getsentry/sentry-dart/pull/1672))
- Add `attachScreenshotOnlyWhenResumed` to options ([#1700](https://github.com/getsentry/sentry-dart/pull/1700))

### Dependencies

- Bump Android SDK from v6.32.0 to v6.33.1 ([#1710](https://github.com/getsentry/sentry-dart/pull/1710), [#1713](https://github.com/getsentry/sentry-dart/pull/1713))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#6331)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.32.0...6.33.1)
- Bump Cocoa SDK from v8.14.2 to v8.15.2 ([#1712](https://github.com/getsentry/sentry-dart/pull/1712), [#1714](https://github.com/getsentry/sentry-dart/pull/1714), [#1717](https://github.com/getsentry/sentry-dart/pull/1717))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8152)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.14.2...8.15.2)

## 7.12.0

### Enhancements

- Log warning if both tracesSampleRate and tracesSampler are set ([#1701](https://github.com/getsentry/sentry-dart/pull/1701))
- Better Flutter framework stack traces - we now collect Flutter framework debug symbols for iOS, macOS and Android automatically on the Sentry server ([#1673](https://github.com/getsentry/sentry-dart/pull/1673))

### Features

- Initial (alpha) support for profiling on iOS and macOS ([#1611](https://github.com/getsentry/sentry-dart/pull/1611))
- Add `SentryNavigatorObserver` current route to `event.app.contexts.viewNames` ([#1545](https://github.com/getsentry/sentry-dart/pull/1545))
  - Requires relay version [23.9.0](https://github.com/getsentry/relay/blob/master/CHANGELOG.md#2390) for self-hosted instances

## 7.11.0

### Fixes

- Session: missing mechanism.handled is considered crash ([#3353](https://github.com/getsentry/sentry-cocoa/pull/3353))

### Features

- Breadcrumbs for file I/O operations ([#1649](https://github.com/getsentry/sentry-dart/pull/1649))

### Dependencies

- Enable compatibility with uuid v4 ([#1647](https://github.com/getsentry/sentry-dart/pull/1647))
- Bump Android SDK from v6.29.0 to v6.32.0 ([#1660](https://github.com/getsentry/sentry-dart/pull/1660), [#1676](https://github.com/getsentry/sentry-dart/pull/1676), [#1688](https://github.com/getsentry/sentry-dart/pull/1688))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#6320)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.29.0...6.32.0)
- Bump Cocoa SDK from v8.11.0 to v8.14.2 ([#1650](https://github.com/getsentry/sentry-dart/pull/1650), [#1655](https://github.com/getsentry/sentry-dart/pull/1655), [#1677](https://github.com/getsentry/sentry-dart/pull/1677), [#1691](https://github.com/getsentry/sentry-dart/pull/1691))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8142)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.11.0...8.14.2)

## 7.10.1

### Enhancements

- Add Sampling Decision to Trace Envelope Header ([#1639](https://github.com/getsentry/sentry-dart/pull/1639))
- Add http.request.method attribute to http spans data ([#1633](https://github.com/getsentry/sentry-dart/pull/1633))
- Add db.system and db.name attributes to db spans data ([#1629](https://github.com/getsentry/sentry-dart/pull/1629))
- Log SDK errors to the console if the log level is `fatal` even if `debug` is disabled ([#1635](https://github.com/getsentry/sentry-dart/pull/1635))

### Features

- Tracing without performance ([#1621](https://github.com/getsentry/sentry-dart/pull/1621))

### Fixes

- Normalize data properties of `SentryUser` and `Breadcrumb` before sending over method channel ([#1591](https://github.com/getsentry/sentry-dart/pull/1591))
- Fixing memory leak issue in SentryFlutterPlugin (Android Plugin) ([#1588](https://github.com/getsentry/sentry-dart/pull/1588))
- Discard empty stack frames ([#1625](https://github.com/getsentry/sentry-dart/pull/1625))
- Disable scope sync for cloned scopes ([#1628](https://github.com/getsentry/sentry-dart/pull/1628))

### Dependencies

- Bump Android SDK from v6.25.2 to v6.29.0 ([#1586](https://github.com/getsentry/sentry-dart/pull/1586), [#1630](https://github.com/getsentry/sentry-dart/pull/1630))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#6290)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.25.2...6.29.0)
- Bump Cocoa SDK from v8.9.1 to v8.11.0 ([#1584](https://github.com/getsentry/sentry-dart/pull/1584), [#1606](https://github.com/getsentry/sentry-dart/pull/1606), [#1626](https://github.com/getsentry/sentry-dart/pull/1626))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#8110)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.9.1...8.11.0)

## 7.9.0

### Features

- Send trace origin ([#1534](https://github.com/getsentry/sentry-dart/pull/1534))

[Trace origin](https://develop.sentry.dev/sdk/performance/trace-origin/) indicates what created a trace or a span. Not all transactions and spans contain enough information to tell whether the user or what precisely in the SDK created it. Origin solves this problem. The SDK now sends origin for transactions and spans.

- Add `appHangTimeoutInterval` to `SentryFlutterOptions` ([#1568](https://github.com/getsentry/sentry-dart/pull/1568))
- DioEventProcessor: Append http response body ([#1557](https://github.com/getsentry/sentry-dart/pull/1557))
  - This is opt-in and depends on `maxResponseBodySize`
  - Only for `dio` package

### Dependencies

- Bump Cocoa SDK from v8.8.0 to v8.9.1 ([#1553](https://github.com/getsentry/sentry-dart/pull/1553))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#891)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.8.0...8.9.1)
- Bump Android SDK from v6.23.0 to v6.25.2 ([#1554](https://github.com/getsentry/sentry-dart/pull/1554))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#6252)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.23.0...6.25.2)

## 7.8.0

### Enhancements

- Add `apiTarget` field to `SentryRequest` and `data` field to `SentryResponse` ([#1517](https://github.com/getsentry/sentry-dart/pull/1517))

### Dependencies

- Bump Android SDK from v6.21.0 to v6.23.0 ([#1512](https://github.com/getsentry/sentry-dart/pull/1512), [#1520](https://github.com/getsentry/sentry-dart/pull/1520))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#6230)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.21.0...6.23.0)
- Bump Cocoa SDK from v8.7.3 to v8.8.0 ([#1521](https://github.com/getsentry/sentry-dart/pull/1521))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#880)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.7.3...8.8.0)

## 7.7.0

### Fixes

- Enums use its name instead of non exhaustive switches ([##1506](https://github.com/getsentry/sentry-dart/pull/#1506))

### Enhancements

- Add http fields to `span.data` ([#1497](https://github.com/getsentry/sentry-dart/pull/1497))
  - Set `http.response.status_code`
  - Set `http.response_content_length`
- Improve `SentryException#value`, remove stringified stack trace ([##1470](https://github.com/getsentry/sentry-dart/pull/#1470))

### Dependencies

- Bump Android SDK from v6.20.0 to v6.21.0 ([#1500](https://github.com/getsentry/sentry-dart/pull/1500))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#6210)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.20.0...6.21.0)

## 7.6.3

### Fixes

- Check if the Native SDKs are enabled when using `autoInitializeNativeSdk=false` ([#1489](https://github.com/getsentry/sentry-dart/pull/1489))
- Align http method to span convention ([#1477](https://github.com/getsentry/sentry-dart/pull/1477))
- Wrapped methods return a `Future` instead of executing right away ([#1476](https://github.com/getsentry/sentry-dart/pull/1476))
  - Relates to ([#1462](https://github.com/getsentry/sentry-dart/pull/1462))
- Fix readTimeoutMillis wrongly configures connectionTimeoutMillis instead of the correct field ([#1485](https://github.com/getsentry/sentry-dart/pull/1485))

### Dependencies

- Bump Android SDK from v6.19.0 to v6.20.0 ([#1466](https://github.com/getsentry/sentry-dart/pull/1466), [#1491](https://github.com/getsentry/sentry-dart/pull/1491))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#6200)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.19.0...6.20.0)
- Bump Cocoa SDK from v8.7.2 to v8.7.3 ([#1487](https://github.com/getsentry/sentry-dart/pull/1487))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#873)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.7.2...8.7.3)

## 7.6.2

### Enhancements

- `SentryAssetBundle` returns Future by default ([#1462](https://github.com/getsentry/sentry-dart/pull/1462))

### Features

- Support `http` >= 1.0.0 ([#1475](https://github.com/getsentry/sentry-dart/pull/1475))

### Dependencies

- Bump Android SDK from v6.18.1 to v6.19.0 ([#1455](https://github.com/getsentry/sentry-dart/pull/1455))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#6190)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.18.1...6.19.0)
- Bump Cocoa SDK from v8.7.1 to v8.7.2 ([#1458](https://github.com/getsentry/sentry-dart/pull/1458))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#872)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.7.1...8.7.2)

## 7.6.1

### Features

- Add `sent_at` to envelope header ([#1428](https://github.com/getsentry/sentry-dart/pull/1428))

### Fixes

- Fix battery level conversion for iOS 16.4 ([#1433](https://github.com/getsentry/sentry-dart/pull/1433))
- Adds a namespace for compatibility with AGP 8.0. ([#1427](https://github.com/getsentry/sentry-dart/pull/1427))
- Avoid dependency conflict with package_info_plus v4 ([#1440](https://github.com/getsentry/sentry-dart/pull/1440))

### Breaking Changes

- Android `minSdkVersion` is now 19 (Flutter already defines 19-20 as best effort)
- Deprecate `extra` in favor of `contexts` ([#1435](https://github.com/getsentry/sentry-dart/pull/1435))

### Dependencies

- Bump Cocoa SDK from v8.5.0 to v8.7.1 ([#1449](https://github.com/getsentry/sentry-dart/pull/1449))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#871)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.5.0...8.7.1)

## 7.5.2

### Fixes

- Fix `event.origin` and `event.environment` on unhandled exceptions ([#1419](https://github.com/getsentry/sentry-dart/pull/1419))
- Fix authority redaction ([#1424](https://github.com/getsentry/sentry-dart/pull/1424))

### Dependencies

- Bump Android SDK from v6.17.0 to v6.18.1 ([#1415](https://github.com/getsentry/sentry-dart/pull/1415))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#6181)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.17.0...6.18.1)

## 7.5.1

### Fixes

- Fallback Uri parsing to `unknown` if its invalid ([#1414](https://github.com/getsentry/sentry-dart/pull/1414))

## 7.5.0

### Features

- Add `SentryIOOverridesIntegration` that automatically wraps `File` into `SentryFile` ([#1362](https://github.com/getsentry/sentry-dart/pull/1362))

```dart
import 'package:sentry_file/sentry_file.dart';

// SDK init. options
options.addIntegration(SentryIOOverridesIntegration());
```

- Add `enableTracing` option ([#1395](https://github.com/getsentry/sentry-dart/pull/1395))
  - This change is backwards compatible. The default is `null` meaning existing behaviour remains unchanged (setting either `tracesSampleRate` or `tracesSampler` enables performance).
  - If set to `true`, performance is enabled, even if no `tracesSampleRate` or `tracesSampler` have been configured.
  - If set to `true`, sampler will use default sample rate of 1.0, if no `tracesSampleRate` is set.
  - If set to `false` performance is disabled, regardless of `tracesSampleRate` and `tracesSampler` options.

```dart
// SDK init. options
options.enableTracing = true;
```

- Sync `connectionTimeout` and `readTimeout` to Android ([#1397](https://github.com/getsentry/sentry-dart/pull/1397))

```dart
// SDK init. options
options.connectionTimeout = Duration(seconds: 10);
options.readTimeout = Duration(seconds: 10);
```

- Set User `name` and `geo` in native plugins ([#1393](https://github.com/getsentry/sentry-dart/pull/1393))

```dart
Sentry.configureScope(
  (scope) => scope.setUser(SentryUser(
      id: '1234',
      name: 'Jane Doe',
      email: 'jane.doe@example.com',
      geo: SentryGeo(
        city: 'Vienna',
        countryCode: 'AT',
        region: 'Austria',
      ))),
);
```

- Add processor count to device info ([#1402](https://github.com/getsentry/sentry-dart/pull/1402))
- Add attachments to `Hint` ([#1404](https://github.com/getsentry/sentry-dart/pull/1404))

```dart
import 'dart:convert';

options.beforeSend = (event, {hint}) {
  final text = 'This event should not be sent happen in prod. Investigate.';
  final textAttachment = SentryAttachment.fromIntList(
    utf8.encode(text),
    'event_info.txt',
    contentType: 'text/plain',
  );
  hint?.attachments.add(textAttachment);
  return event;
};
```

### Fixes

- Screenshots and View Hierarchy should only be added to errors ([#1385](https://github.com/getsentry/sentry-dart/pull/1385))
  - View Hierarchy is removed from Web errors since we don't symbolicate minified View Hierarchy yet.
- More improvements related to not awaiting `FutureOr<T>` if it's not a future ([#1385](https://github.com/getsentry/sentry-dart/pull/1385))
- Do not report only async gap frames for logging calls ([#1398](https://github.com/getsentry/sentry-dart/pull/1398))

### Dependencies

- Bump Cocoa SDK from v8.4.0 to v8.5.0 ([#1394](https://github.com/getsentry/sentry-dart/pull/1394))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#850)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.4.0...8.5.0)

## 7.4.2

### Fixes

- Fix breadcrumbs not being sent on Android web ([#1378](https://github.com/getsentry/sentry-dart/pull/1378))

## 7.4.1

### Fixes

- Fix Dart web builds breaking due to `dart:io` imports when using `SentryIsolate` or `SentryIsolateExtension` ([#1371](https://github.com/getsentry/sentry-dart/pull/1371))
  - When using `SentryIsolate` or `SentryIsolateExtension`, import `sentry_io.dart`.
- Export `SentryBaggage` ([#1377](https://github.com/getsentry/sentry-dart/pull/1377))
- Remove breadcrumbs from transaction to avoid duplication ([#1366](https://github.com/getsentry/sentry-dart/pull/1366))

### Dependencies

- Bump Cocoa SDK from v8.3.3 to v8.4.0 ([#1379](https://github.com/getsentry/sentry-dart/pull/1379))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#840)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.3.3...8.4.0)
- Bump Android SDK from v6.16.0 to v6.17.0 ([#1374](https://github.com/getsentry/sentry-dart/pull/1374))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#6170)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.16.0...6.17.0)

## 7.4.0

### Features

- SentryUserInteractionWidget: add support for PopupMenuButton and PopupMenuItem ([#1361](https://github.com/getsentry/sentry-dart/pull/1361))

### Fixes

- Fix `SentryUserInteractionWidget` throwing when Sentry is not enabled ([#1363](https://github.com/getsentry/sentry-dart/pull/1363))
- Fix enableAutoNativeBreadcrumbs and enableNativeCrashHandling sync flags ([#1367](https://github.com/getsentry/sentry-dart/pull/1367))

## 7.3.0

### Features

- Sanitize sensitive data from URLs (span desc, span data, crumbs, client errors) ([#1327](https://github.com/getsentry/sentry-dart/pull/1327))

### Dependencies

- Bump Cocoa SDK from v8.3.1 to v8.3.3 ([#1350](https://github.com/getsentry/sentry-dart/pull/1350), [#1355](https://github.com/getsentry/sentry-dart/pull/1355))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#833)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.3.1...8.3.3)

### Fixes

- Sync missing properties to the Native SDKs ([#1354](https://github.com/getsentry/sentry-dart/pull/1354))

## 7.2.0

### Features

- sqflite Support for Flutter ([#1306](https://github.com/getsentry/sentry-dart/pull/1306))

### Fixes

- `DioErrorExtractor` no longer extracts `DioError.stackTrace` which is done via `DioStackTraceExtractor` instead ([#1344](https://github.com/getsentry/sentry-dart/pull/1344))
- LoadImageListIntegration won't throw bad state if there is no exceptions in the event ([#1347](https://github.com/getsentry/sentry-dart/pull/1347))

### Dependencies

- Bump Android SDK from v6.15.0 to v6.16.0 ([#1342](https://github.com/getsentry/sentry-dart/pull/1342))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#6160)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.15.0...6.16.0)

## 7.1.0

### Features

- Exception StackTrace Extractor ([#1335](https://github.com/getsentry/sentry-dart/pull/1335))

### Dependencies

- Bump Cocoa SDK from v8.0.0 to v8.3.1 ([#1331](https://github.com/getsentry/sentry-dart/pull/1331))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#831)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.0.0...8.3.1)

### Fixes

- SentryUserInteractionWidget checks if the Elements are mounted before comparing them ([#1339](https://github.com/getsentry/sentry-dart/pull/1339))

## 7.0.0

### Features

- Platform Exception Event Processor ([#1297](https://github.com/getsentry/sentry-dart/pull/1297))
- Support failedRequestTargets for HTTP Client errors ([#1285](https://github.com/getsentry/sentry-dart/pull/1285))
  - Captures errors for the default range `500-599` if `captureFailedRequests` is enabled
- Sentry Isolate Extension ([#1266](https://github.com/getsentry/sentry-dart/pull/1266))
- Allow sentry user to control resolution of captured Flutter screenshots ([#1288](https://github.com/getsentry/sentry-dart/pull/1288))
- Support beforeSendTransaction ([#1238](https://github.com/getsentry/sentry-dart/pull/1238))
- Add In Foreground to App context ([#1260](https://github.com/getsentry/sentry-dart/pull/1260))
- Error Cause Extractor ([#1198](https://github.com/getsentry/sentry-dart/pull/1198), [#1236](https://github.com/getsentry/sentry-dart/pull/1236))
  - Add `throwable` to `SentryException`
- Dart 3 Support ([#1220](https://github.com/getsentry/sentry-dart/pull/1220))
- Introduce `Hint` data bag ([#1136](https://github.com/getsentry/sentry-dart/pull/1136))
- Use `Hint` for screenshots ([#1165](https://github.com/getsentry/sentry-dart/pull/1165))
- Support custom units for custom measurements ([#1181](https://github.com/getsentry/sentry-dart/pull/1181))

### Enhancements

- Replace `toImage` with `toImageSync` for Flutter >= 3.7 ([1268](https://github.com/getsentry/sentry-dart/pull/1268))
- Don't await `FutureOr<T>` if it's not a future. This should marginally improve the performance ([#1310](https://github.com/getsentry/sentry-dart/pull/1310))
- Replace `StackTrace.empty` with `StackTrace.current` ([#1183](https://github.com/getsentry/sentry-dart/pull/1183))

### Breaking Changes

[Dart Migration guide](https://docs.sentry.io/platforms/dart/migration/#migrating-from-sentry-618x-to-sentry-700).

[Flutter Migration guide](https://docs.sentry.io/platforms/flutter/migration/#migrating-from-sentry_flutter-618x-to-sentry-700).

- Enable enableNdkScopeSync by default ([#1276](https://github.com/getsentry/sentry-dart/pull/1276))
- Update `sentry_dio` to dio v5 ([#1282](https://github.com/getsentry/sentry-dart/pull/1282))
- Remove deprecated fields ([#1227](https://github.com/getsentry/sentry-dart/pull/1227))
  - Remove deprecated fields from the `Scope` class.
    - `user(SentryUser? user)`, using the `setUser(SentryUser? user)` instead.
    - `attachements`, using the `attachments` instead.
  - Remove deprecated field from the `SentryFlutterOptions` class.
    - `anrTimeoutIntervalMillis`, using the `anrTimeoutInterval` instead.
    - `autoSessionTrackingIntervalMillis`, using the `autoSessionTrackingInterval` instead.
- Rename APM tracking feature flags to tracing ([#1222](https://github.com/getsentry/sentry-dart/pull/1222))
  - Rename
    - enableAutoPerformanceTracking to enableAutoPerformanceTracing
    - enableOutOfMemoryTracking to enableWatchdogTerminationTracking
- Enable APM features by default ([#1217](https://github.com/getsentry/sentry-dart/pull/1217))
  - Enable by default
    - captureFailedRequests
    - enableStructuredDataTracing
    - enableUserInteractionTracing
- Mark transaction as internal_error in case of unhandled errors ([#1218](https://github.com/getsentry/sentry-dart/pull/1218))
- Removed various deprecated fields ([#1036](https://github.com/getsentry/sentry-dart/pull/1036)):
  - Removed the following fields from the `device` context
    - language
    - timezone
    - screenResolution
    - theme
  - Removed isolate name from Dart context. It's now reported via the threads interface. It can be enabled via `options.attachThreads`
- Use `sentryClientName` instead of `sdk.identifier` ([#1135](https://github.com/getsentry/sentry-dart/pull/1135))
- Refactor `BindingUtils` to `BindingWrapper` to enable the use of custom bindings ([#1184](https://github.com/getsentry/sentry-dart/pull/1184))
- Bump Flutter min to 3.0.0 and Dart to 2.17.0 ([#1180](https://github.com/getsentry/sentry-dart/pull/1180))

### Dependencies

- Bump Cocoa SDK from 7.31.5 to 8.0.0
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#800)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/7.31.5...8.0.0)

### Fixes

- View hierarchy reads size from RenderBox only ([#1258](https://github.com/getsentry/sentry-dart/pull/1258))
- Try to avoid ConcurrentModificationError by not using a Future.forEach ([#1259](https://github.com/getsentry/sentry-dart/pull/1259))
- isWeb check for WASM ([#1249](https://github.com/getsentry/sentry-dart/pull/1249))
- Don't suppress error logs ([#1228](https://github.com/getsentry/sentry-dart/pull/1228))
- Fix: Remove `SentryOptions` related parameters from classes which also take `Hub` as a parameter (#816)

## 7.0.0-rc.2

### Features

- Platform Exception Event Processor ([#1297](https://github.com/getsentry/sentry-dart/pull/1297))
- Support failedRequestTargets for HTTP Client errors ([#1285](https://github.com/getsentry/sentry-dart/pull/1285))
  - Captures errors for the default range `500-599` if `captureFailedRequests` is enabled
- Sentry Isolate Extension ([#1266](https://github.com/getsentry/sentry-dart/pull/1266))
- Allow sentry user to control resolution of captured Flutter screenshots ([#1288](https://github.com/getsentry/sentry-dart/pull/1288))

### Enhancements

- Replace `toImage` with `toImageSync` for Flutter >= 3.7 ([1268](https://github.com/getsentry/sentry-dart/pull/1268))
- Don't await `FutureOr<T>` if it's not a future. This should marginally improve the performance ([#1310](https://github.com/getsentry/sentry-dart/pull/1310))

## 6.22.0

### Features

- Add proguard_uui property to SentryFlutterOptions to set proguard information at runtime ([#1312](https://github.com/getsentry/sentry-dart/pull/1312))

### Fixes

- Change podspec `EXCLUDED_ARCHS` value to allow podfiles to add more excluded architetures ([#1303](https://github.com/getsentry/sentry-dart/pull/1303))

### Dependencies

- Bump Android SDK from v6.13.1 to v6.15.0 ([#1287](https://github.com/getsentry/sentry-dart/pull/1287), [#1311](https://github.com/getsentry/sentry-dart/pull/1311))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#6150)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.13.1...6.15.0)

## 7.0.0-rc.1

### Breaking Changes

- Enable enableNdkScopeSync by default ([#1276](https://github.com/getsentry/sentry-dart/pull/1276))
- Update `sentry_dio` to dio v5 ([#1282](https://github.com/getsentry/sentry-dart/pull/1282))

### Dependencies

- Bump Android SDK from v6.13.1 to v6.14.0 ([#1287](https://github.com/getsentry/sentry-dart/pull/1287))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#6140)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.13.1...6.14.0)

## 6.21.0

### Features

- Implement `loadStructuredBinaryData` from updated AssetBundle ([#1272](https://github.com/getsentry/sentry-dart/pull/1272))

### Dependencies

- Bump Android SDK from v6.13.0 to v6.13.1 ([#1273](https://github.com/getsentry/sentry-dart/pull/1273))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#6131)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.13.0...6.13.1)

### Fixes

- Pass processed Breadcrumb to scope observer ([#1298](https://github.com/getsentry/sentry-dart/pull/1298))
- Remove duplicated breadcrumbs when syncing with iOS/macOS ([#1283](https://github.com/getsentry/sentry-dart/pull/1283))

## 6.20.1

### Fixes

- Set client name with version in Android SDK ([#1274](https://github.com/getsentry/sentry-dart/pull/1274))

## 7.0.0-beta.4

### Features

- Support beforeSendTransaction ([#1238](https://github.com/getsentry/sentry-dart/pull/1238))
- Add In Foreground to App context ([#1260](https://github.com/getsentry/sentry-dart/pull/1260))

### Fixes

- View hierarchy reads size from RenderBox only ([#1258](https://github.com/getsentry/sentry-dart/pull/1258))
- Try to avoid ConcurrentModificationError by not using a Future.forEach ([#1259](https://github.com/getsentry/sentry-dart/pull/1259))

### Dependencies

- Bump Android SDK from v6.12.1 to v6.13.0 ([#1250](https://github.com/getsentry/sentry-dart/pull/1250))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#6130)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.12.1...6.13.0)

## 7.0.0-beta.1

### Fixes

- isWeb check for WASM ([#1249](https://github.com/getsentry/sentry-dart/pull/1249))

## 7.0.0-alpha.5

### Features

- Error Cause Extractor ([#1198](https://github.com/getsentry/sentry-dart/pull/1198), [#1236](https://github.com/getsentry/sentry-dart/pull/1236))
  - Add `throwable` to `SentryException`

### Fixes

- Don't suppress error logs ([#1228](https://github.com/getsentry/sentry-dart/pull/1228))
- Fix export for `BindingWrapper` ([#1234](https://github.com/getsentry/sentry-dart/pull/1234))

## 7.0.0-alpha.4

### Breaking Changes

- Remove deprecated fields ([#1227](https://github.com/getsentry/sentry-dart/pull/1227))
  - Remove deprecated fields from the `Scope` class.
    - `user(SentryUser? user)`, using the `setUser(SentryUser? user)` instead.
    - `attachements`, using the `attachments` instead.
  - Remove deprecated field from the `SentryFlutterOptions` class.
    - `anrTimeoutIntervalMillis`, using the `anrTimeoutInterval` instead.
    - `autoSessionTrackingIntervalMillis`, using the `autoSessionTrackingInterval` instead.

### Dependencies

- Bump Cocoa SDK from 8.0.0-rc.1 to 8.0.0
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/main/CHANGELOG.md#800)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/8.0.0-rc.1...8.0.0)

## 7.0.0-alpha.3

### Breaking Changes

- Rename APM tracking feature flags to tracing ([#1222](https://github.com/getsentry/sentry-dart/pull/1222))
  - Rename
    - enableAutoPerformanceTracking to enableAutoPerformanceTracing
    - enableOutOfMemoryTracking to enableWatchdogTerminationTracking

### Enhancements

- Migrate to sentry cocoa v8 ([#1197](https://github.com/getsentry/sentry-dart/pull/1197))

## 7.0.0-alpha.2

### Features

- Dart 3 Support ([#1220](https://github.com/getsentry/sentry-dart/pull/1220))

### Breaking Changes

- Enable APM features by default ([#1217](https://github.com/getsentry/sentry-dart/pull/1217))
  - Enable by default
    - captureFailedRequests
    - enableStructuredDataTracing
    - enableUserInteractionTracing
- Mark transaction as internal_error in case of unhandled errors ([#1218](https://github.com/getsentry/sentry-dart/pull/1218))

## 7.0.0-alpha.1

### Features

- Feat: Introduce `Hint` data bag ([#1136](https://github.com/getsentry/sentry-dart/pull/1136))
- Feat: Use `Hint` for screenshots ([#1165](https://github.com/getsentry/sentry-dart/pull/1165))
- Feat: Support custom units for custom measurements ([#1181](https://github.com/getsentry/sentry-dart/pull/1181))

### Fixes

- Fix: Remove `SentryOptions` related parameters from classes which also take `Hub` as a parameter (#816)

### Enhancements

- Enha: Replace `StackTrace.empty` with `StackTrace.current` ([#1183](https://github.com/getsentry/sentry-dart/pull/1183))

### Breaking Changes

- Removed various deprecated fields ([#1036](https://github.com/getsentry/sentry-dart/pull/1036)):
  - Removed the following fields from the `device` context
    - language
    - timezone
    - screenResolution
    - theme
  - Removed isolate name from Dart context. It's now reported via the threads interface. It can be enabled via `options.attachThreads`
- Use `sentryClientName` instead of `sdk.identifier` ([#1135](https://github.com/getsentry/sentry-dart/pull/1135))
- Refactor `BindingUtils` to `BindingWrapper` to enable the use of custom bindings ([#1184](https://github.com/getsentry/sentry-dart/pull/1184))
- Bump Flutter min to 3.0.0 and Dart to 2.17.0 ([#1180](https://github.com/getsentry/sentry-dart/pull/1180))

## 6.19.0

### Fixes

- intl is now more version permissive (>=0.17.0 <1.0.0) ([#1247](https://github.com/getsentry/sentry-dart/pull/1247))

### Breaking Changes:

- sentry_file now requires Dart >= 2.19 ([#1240](https://github.com/getsentry/sentry-dart/pull/1240))

## 6.18.3

### Fixes

- Fix Pod target for iOS ([#1237](https://github.com/getsentry/sentry-dart/pull/1237))

### Dependencies

- Bump Android SDK from v6.11.0 to v6.12.1 ([#1225](https://github.com/getsentry/sentry-dart/pull/1225), [#1230](https://github.com/getsentry/sentry-dart/pull/1230))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#6121)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.11.0...6.12.1)

## 6.18.2

### Fixes

- enableUserInteractionTracing sometimes finds the wrong widget ([#1212](https://github.com/getsentry/sentry-dart/pull/1212))
- Only call method channels on native platforms ([#1196](https://github.com/getsentry/sentry-dart/pull/1196))

### Dependencies

- Bump Android SDK from v6.9.2 to v6.11.0 ([#1194](https://github.com/getsentry/sentry-dart/pull/1194), [#1209](https://github.com/getsentry/sentry-dart/pull/1209))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#6110)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.9.2...6.11.0)
- Bump Cocoa SDK from v7.31.3 to v7.31.5 ([#1190](https://github.com/getsentry/sentry-dart/pull/1190), [#1207](https://github.com/getsentry/sentry-dart/pull/1207))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/8.0.0/CHANGELOG.md#7315)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/7.31.3...7.31.5)

## 6.18.1

### Fixes

- Missing slow and frozen frames for Auto transactions ([#1172](https://github.com/getsentry/sentry-dart/pull/1172))

### Dependencies

- Bump Android SDK from v6.9.1 to v6.9.2 ([#1167](https://github.com/getsentry/sentry-dart/pull/1167))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#692)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.9.1...6.9.2)

## 6.18.0

### Features

- Tracing for File IO integration ([#1160](https://github.com/getsentry/sentry-dart/pull/1160))

### Dependencies

- Bump Cocoa SDK from v7.31.2 to v7.31.3 ([#1157](https://github.com/getsentry/sentry-dart/pull/1157))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/master/CHANGELOG.md#7313)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/7.31.2...7.31.3)
- Bump Android SDK from v6.8.0 to v6.9.1 ([#1159](https://github.com/getsentry/sentry-dart/pull/1159))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#691)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.8.0...6.9.1)

## 6.17.0

### Fixes

- Capture Future errors for Flutter Web automatically ([#1152](https://github.com/getsentry/sentry-dart/pull/1152))

### Features

- User Interaction transactions and breadcrumbs ([#1137](https://github.com/getsentry/sentry-dart/pull/1137))

## 6.16.1

### Fixes

- Do not attach headers if Span is NoOp ([#1143](https://github.com/getsentry/sentry-dart/pull/1143))

### Dependencies

- Bump Cocoa SDK from v7.31.1 to v7.31.2 ([#1146](https://github.com/getsentry/sentry-dart/pull/1146))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/master/CHANGELOG.md#7312)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/7.31.1...7.31.2)
- Bump Android SDK from v6.7.1 to v6.8.0 ([#1147](https://github.com/getsentry/sentry-dart/pull/1147))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#680)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.7.1...6.8.0)

## 6.16.0

### Features

- Add request context to `HttpException`, `SocketException` and `NetworkImageLoadException` ([#1118](https://github.com/getsentry/sentry-dart/pull/1118))
- `SocketException` and `FileSystemException` with `OSError`s report the `OSError` as root exception ([#1118](https://github.com/getsentry/sentry-dart/pull/1118))

### Fixes

- VendorId should be a String ([#1112](https://github.com/getsentry/sentry-dart/pull/1112))
- Disable `enableUserInteractionBreadcrumbs` on Android when `enableAutoNativeBreadcrumbs` is disabled ([#1131](https://github.com/getsentry/sentry-dart/pull/1131))
- Transaction name is reset after the transaction finishes ([#1125](https://github.com/getsentry/sentry-dart/pull/1125))

### Dependencies

- Bump Cocoa SDK from v7.30.2 to v7.31.1 ([#1132](https://github.com/getsentry/sentry-dart/pull/1132), [#1139](https://github.com/getsentry/sentry-dart/pull/1139))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/master/CHANGELOG.md#7311)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/7.30.2...7.31.1)
- Bump Android SDK from v6.7.0 to v6.7.1 ([#1112](https://github.com/getsentry/sentry-dart/pull/1112))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#671)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.7.0...6.7.1)

## 6.15.1

### Dependencies

- Bump Cocoa SDK from v7.30.1 to v7.30.2 ([#1113](https://github.com/getsentry/sentry-dart/pull/1113))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/master/CHANGELOG.md#7302)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/7.30.1...7.30.2)

## 6.15.0

### Features

- Feat: Screenshot Attachment ([#1088](https://github.com/getsentry/sentry-dart/pull/1088))

### Fixes

- Merging of integrations and packages ([#1111](https://github.com/getsentry/sentry-dart/pull/1111))
- Add missing `fragment` for HTTP Client Errors ([#1102](https://github.com/getsentry/sentry-dart/pull/1102))
- Sync user name and geo for Android ([#1102](https://github.com/getsentry/sentry-dart/pull/1102))
- Add mechanism to Dio Http Client error ([#1114](https://github.com/getsentry/sentry-dart/pull/1114))

### Dependencies

- Bump Android SDK from v6.6.0 to v6.7.0 ([#1105](https://github.com/getsentry/sentry-dart/pull/1105))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#670)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.6.0...6.7.0)
- Bump Cocoa SDK from v7.30.0 to v7.30.1 ([#1104](https://github.com/getsentry/sentry-dart/pull/1104))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/master/CHANGELOG.md#7301)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/7.30.0...7.30.1)

## 6.14.0

### Features

- Capture response information in `SentryHttpClient` ([#1095](https://github.com/getsentry/sentry-dart/pull/1095))

### Changes

- Remove experimental `SentryResponse` fields: `url`, `body`, `redirected`, `status` ([#1095](https://github.com/getsentry/sentry-dart/pull/1095))
- `SentryHttpClient` request body capture checks default PII capture setting, same as the DIO integration ([#1095](https://github.com/getsentry/sentry-dart/pull/1095))

### Dependencies

- Bump Android SDK from v6.5.0 to v6.6.0 ([#1090](https://github.com/getsentry/sentry-dart/pull/1090))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#660)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.5.0...6.6.0)
- Bump Cocoa SDK from v7.28.0 to v7.30.0 ([#1089](https://github.com/getsentry/sentry-dart/pull/1089), [#1101](https://github.com/getsentry/sentry-dart/pull/1101))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/master/CHANGELOG.md#7300)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/7.28.0...7.30.0)

## 6.13.1

### Fixes

- Avoid dependency conflict with package_info_plus v3 ([#1084](https://github.com/getsentry/sentry-dart/pull/1084))

## 6.13.0

### Features

- Use PlatformDispatcher.onError in Flutter 3.3 ([#1039](https://github.com/getsentry/sentry-dart/pull/1039))

### Fixes

- Bring protocol up to date with latest Sentry protocol ([#1038](https://github.com/getsentry/sentry-dart/pull/1038))

### Dependencies

- Bump Cocoa SDK from v7.27.1 to v7.28.0 ([#1080](https://github.com/getsentry/sentry-dart/pull/1080))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/master/CHANGELOG.md#7280)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/7.27.1...7.28.0)

## 6.12.2

### Fixes

- Avoid dependency conflict with package_info_plus v2 ([#1068](https://github.com/getsentry/sentry-dart/pull/1068))

## 6.12.1

### Dependencies

- Bump Android SDK from v6.4.3 to v6.5.0 ([#1062](https://github.com/getsentry/sentry-dart/pull/1062), [#1064](https://github.com/getsentry/sentry-dart/pull/1064))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#650)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.4.3...6.5.0)

## 6.12.0

### Fixes

- Handle traces sampler exception ([#1040](https://github.com/getsentry/sentry-dart/pull/1040))
- tracePropagationTargets ignores invalid Regex ([#1043](https://github.com/getsentry/sentry-dart/pull/1043))
- SentryDevice cast error ([#1059](https://github.com/getsentry/sentry-dart/pull/1059))

### Features

- Added [Flutter renderer](https://docs.flutter.dev/development/platform-integration/web/renderers) information to events ([#1035](https://github.com/getsentry/sentry-dart/pull/1035))
- Added missing DSN field into the SentryEnvelopeHeader ([#1050](https://github.com/getsentry/sentry-dart/pull/1050))

### Dependencies

- Bump Android SDK from v6.4.2 to v6.4.3 ([#1048](https://github.com/getsentry/sentry-dart/pull/1048))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#643)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.4.2...6.4.3)
- Bump Cocoa SDK from v7.27.0 to v7.27.1 ([#1049](https://github.com/getsentry/sentry-dart/pull/1049))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/master/CHANGELOG.md#7271)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/7.27.0...7.27.1)

## 6.11.2

### Fixes

- Tracer does not allow setting measurement if finished ([#1026](https://github.com/getsentry/sentry-dart/pull/1026))
- Add missing measurements units ([#1033](https://github.com/getsentry/sentry-dart/pull/1033))

### Features

- Bump Cocoa SDK from v7.26.0 to v7.27.0 ([#1030](https://github.com/getsentry/sentry-dart/pull/1030))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/master/CHANGELOG.md#7270)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/7.26.0...7.27.0)

## 6.11.1

### Fixes

- Align span spec for serialize ops ([#1024](https://github.com/getsentry/sentry-dart/pull/1024))
- Pin sentry version ([#1020](https://github.com/getsentry/sentry-dart/pull/1020))

### Features

- Bump Cocoa SDK from v7.25.1 to v7.26.0 ([#1023](https://github.com/getsentry/sentry-dart/pull/1023))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/master/CHANGELOG.md#7260)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/7.25.1...7.26.0)

## 6.11.0

### Fixes

- Scope cloning method was not setting the user ([#1013](https://github.com/getsentry/sentry-dart/pull/1013))

### Features

- Dynamic sampling ([#1004](https://github.com/getsentry/sentry-dart/pull/1004))
- Set custom measurements on transactions ([#1011](https://github.com/getsentry/sentry-dart/pull/1011))

## 6.10.0

### Fixes

- Capture Callback Exceptions ([#990](https://github.com/getsentry/sentry-dart/pull/990))
- Allow routeNameExtractor to set transaction names ([#1005](https://github.com/getsentry/sentry-dart/pull/1005))

### Features

- Prepare future support for iOS and macOS obfuscated app symbolication using dSYM (requires Flutter `master` channel) ([#823](https://github.com/getsentry/sentry-dart/pull/823))
- Bump Android SDK from v6.3.1 to v6.4.2 ([#989](https://github.com/getsentry/sentry-dart/pull/989), [#1009](https://github.com/getsentry/sentry-dart/pull/1009))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#642)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.3.1...6.4.2)
- Bump Cocoa SDK from v7.23.0 to v7.25.1 ([#993](https://github.com/getsentry/sentry-dart/pull/993), [#996](https://github.com/getsentry/sentry-dart/pull/996), [#1000](https://github.com/getsentry/sentry-dart/pull/1000), [#1007](https://github.com/getsentry/sentry-dart/pull/1007))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/master/CHANGELOG.md#7251)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/7.23.0...7.25.1)

## 6.9.1

### Fixes

- Scope.clone incorrectly accesses tags ([#978](https://github.com/getsentry/sentry-dart/pull/978))
- beforeBreadcrumb was not adding the mutated breadcrumb ([#982](https://github.com/getsentry/sentry-dart/pull/982))

### Features

- Bump Cocoa SDK to v7.23.0 ([#968](https://github.com/getsentry/sentry-dart/pull/968))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/master/CHANGELOG.md#7230)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/7.22.0...7.23.0)
- Bump Android SDK from v6.3.0 to v6.3.1 ([#976](https://github.com/getsentry/sentry-dart/pull/976))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#631)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.3.0...6.3.1)

## 6.9.0

### Features

- Bump Flutter's min. supported version from 1.17.0 to 2.0.0 ([#966](https://github.com/getsentry/sentry-dart/pull/966))

This should not break anything since the Dart's min. version is already 2.12.0 and Flutter 2.0.0 uses Dart 2.12.0

### Fixes

- Back compatibility of Object.hash for Dart 2.12.0 ([#966](https://github.com/getsentry/sentry-dart/pull/966))
- Fix back compatibility for OnErrorIntegration integration ([#965](https://github.com/getsentry/sentry-dart/pull/965))

## 6.8.1

### Fixes

- `Scope#setContexts` pasing a List value would't not work ([#932](https://github.com/getsentry/sentry-dart/pull/932))

### Features

- Add integration for `PlatformDispatcher.onError` ([#915](https://github.com/getsentry/sentry-dart/pull/915))

* Bump Cocoa SDK to v7.22.0 ([#960](https://github.com/getsentry/sentry-dart/pull/960))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/master/CHANGELOG.md#7220)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/7.21.0...7.22.0)

## 6.8.0

### Fixes

- Missing OS context for iOS events ([#958](https://github.com/getsentry/sentry-dart/pull/958))
- Fix: `Scope#clone` calls the Native bridges again via the `scopeObserver` ([#959](https://github.com/getsentry/sentry-dart/pull/959))

### Features

- Dio Integration adds response data ([#934](https://github.com/getsentry/sentry-dart/pull/934))

## 6.7.0

### Fixes

- Maps with Key Object, Object would fail during serialization if not String, Object ([#935](https://github.com/getsentry/sentry-dart/pull/935))
- Breadcrumbs "Concurrent Modification" ([#948](https://github.com/getsentry/sentry-dart/pull/948))
- Duplicative Screen size changed breadcrumbs ([#888](https://github.com/getsentry/sentry-dart/pull/888))
- Duplicated Android Breadcrumbs with no Mechanism ([#954](https://github.com/getsentry/sentry-dart/pull/954))
- Fix windows native method need default result ([#943](https://github.com/getsentry/sentry-dart/pull/943))
- Add request instead of response data to `SentryRequest` in `DioEventProcessor` [#933](https://github.com/getsentry/sentry-dart/pull/933)

### Features

- Bump Android SDK to v6.3.0 ([#945](https://github.com/getsentry/sentry-dart/pull/945), [#950](https://github.com/getsentry/sentry-dart/pull/950))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#630)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.1.4...6.3.0)
- Bump Cocoa SDK to v7.21.0 ([#947](https://github.com/getsentry/sentry-dart/pull/947))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/master/CHANGELOG.md#7210)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/7.19.0...7.21.0)

## 6.6.3

### Fixes

- Context Escape with ScopeCallback ([#925](https://github.com/getsentry/sentry-dart/pull/925))

## 6.6.2

### Features

- Bump Android SDK to v6.1.4 ([#900](https://github.com/getsentry/sentry-dart/pull/900))
  - [changelog](https://github.com/getsentry/sentry-java/blob/main/CHANGELOG.md#614)
  - [diff](https://github.com/getsentry/sentry-java/compare/6.1.2...6.1.4)
- Bump Cocoa SDK to v7.19.0 ([#901](https://github.com/getsentry/sentry-dart/pull/901), [#928](https://github.com/getsentry/sentry-dart/pull/928))
  - [changelog](https://github.com/getsentry/sentry-cocoa/blob/master/CHANGELOG.md#7190)
  - [diff](https://github.com/getsentry/sentry-cocoa/compare/7.18.0...7.19.0)

### Fixes

- Send DidBecomeActiveNotification when OOM enabled (#905)
- `dio.addSentry` hangs if `dsn` is empty and SDK NoOp ([#920](https://github.com/getsentry/sentry-dart/pull/920))
- addBreadcrumb throws on Android API < 24 because of NewApi usage ([#923](https://github.com/getsentry/sentry-dart/pull/923))
- [`sentry_dio`](https://pub.dev/packages/sentry_dio) is promoted to GA and not experimental anymore ([#914](https://github.com/getsentry/sentry-dart/pull/914))

## 6.6.1

### Fixes

- Filter out app starts with more than 60s (#895)

## 6.6.0

### Fixes

- Bump: Sentry-Cocoa to 7.18.0 and Sentry-Android to 6.1.2 (#892)
- Fix: Add missing iOS contexts (#761)
- Fix serialization of threads (#844)
- Fix: `SentryAssetBundle` on Flutter >= 3.1 (#877)

### Features

- Feat: Client Reports (#829)
- Feat: Allow manual init of the Native SDK (#765)
- Feat: Attach Isolate name to thread context (#847)
- Feat: Add Android thread to platform stacktraces (#853)
- Feat: Sync Scope to Native (#858)

### Sentry Self-hosted Compatibility

- Starting with version `6.6.0` of `sentry`, [Sentry's version >= v21.9.0](https://github.com/getsentry/self-hosted/releases) is required or you have to manually disable sending client reports via the `sendClientReports` option. This only applies to self-hosted Sentry. If you are using [sentry.io](https://sentry.io), no action is needed.

## 6.6.0-beta.4

- Bump: Sentry-Cocoa to 7.17.0 and Sentry-Android to 6.1.1 (#891)

## 6.6.0-beta.3

- Bump: Sentry-Cocoa to 7.16.1 (#886)

## 6.6.0-beta.2

- Fix: Add user setter back in the scope (#883)
- Fix: clear method sets all properties synchronously (#882)

## 6.6.0-beta.1

- Feat: Sync Scope to Native (#858)

## 6.6.0-alpha.3

- Feat: Attach Isolate name to thread context (#847)
- Fix: `SentryAssetBundle` on Flutter >= 3.1 (#877)
- Feat: Add Android thread to platform stacktraces (#853)
- Fix: Rename auto initialize property (#857)
- Bump: Sentry-Android to 6.0.0 (#879)

## 6.6.0-alpha.2

- Fix serialization of threads (#844)
- Feat: Allow manual init of the Native SDK (#765)

## 6.6.0-alpha.1

- Feat: Client Reports (#829)
- Fix: Add missing iOS contexts (#761)

### Sentry Self-hosted Compatibility

- Starting with version `6.6.0` of `sentry`, [Sentry's version >= v21.9.0](https://github.com/getsentry/self-hosted/releases) is required or you have to manually disable sending client reports via the `sendClientReports` option. This only applies to self-hosted Sentry. If you are using [sentry.io](https://sentry.io), no action is needed.

## 6.5.1

- Update event contexts (#838)

## 6.5.0

- No documented changes.

## 6.5.0-beta.2

- Fix: Do not set the transaction to scope if no op (#828)

## 6.5.0-beta.1

- No documented changes.

## 6.5.0-alpha.3

- Feat: Support for platform stacktraces on Android (#788)

## 6.5.0-alpha.2

- Bump: Sentry-Android to 5.7.0 and Sentry-Cocoa to 7.11.0 (#796)
- Fix: Dio event processor safelly bails if no DioError in the exception list (#795)

## 6.5.0-alpha.1

- Feat: Mobile Vitals - Native App Start (#749)
- Feat: Mobile Vitals - Native Frames (#772)

## 6.4.0

### Various fixes & improvements

- Fix: Missing userId on iOS when userId is not set (#782) by @marandaneto
- Allow to set startTimestamp & endTimestamp manually to SentrySpan (#676) by @fatihergin

## 6.4.0-beta.3

- Feat: Allow to set startTimestamp & endTimestamp manually to SentrySpan (#676)
- Bump: Sentry-Cocoa to 7.10.0 (#777)
- Feat: Additional Dart/Flutter context information (#778)
- Bump: Kotlin plugin to 1.5.31 (#763)
- Fix: Missing userId on iOS when userId is not set (#782)

## 6.4.0-beta.2

- No documented changes.

## 6.4.0-beta.1

- Fix: Disable log by default in debug mode (#753)
- [Dio] Ref: Replace FailedRequestAdapter with FailedRequestInterceptor (#728)
- Fix: Add missing return values - dart analyzer (#742)
- Feat: Add `DioEventProcessor` which improves DioError crash reports (#718)
- Fix: Do not report duplicated packages and integrations (#760)
- Feat: Allow manual init of the Native SDK or no Native SDK at all (#765)

## 6.3.0

- Feat: Support maxSpan for performance API and expose SentryOptions through Hub (#716)
- Fix: await ZonedGuard integration to run (#732)
- Fix: `sentry_logging` incorrectly setting SDK name (#725)
- Bump: Sentry-Android to 5.6.1 and Sentry-Cocoa to 7.9.0 (#736)
- Feat: Support Attachment.addToTransactions (#709)
- Fix: captureTransaction should return emptyId when transaction is discarded (#713)
- Add `SentryAssetBundle` for automatic spans for asset loading (#685)
- Fix: `maxRequestBodySize` should be `never` by default when using the FailedRequestClientAdapter directly (#701)
- Feat: Add support for [Dio](https://pub.dev/packages/dio) (#688)
- Fix: Use correct data/extras type in tracer (#693)
- Fix: Do not throw when Throwable type is not supported for associating errors to a transaction (#692)
- Feat: Automatically create transactions when navigating between screens (#643)

## 6.3.0-beta.4

- Feat: Support Attachment.addToTransactions (#709)
- Fix: captureTransaction should return emptyId when transaction is discarded (#713)

## 6.3.0-beta.3

- Feat: Auto transactions duration trimming (#702)
- Add `SentryAssetBundle` for automatic spans for asset loading (#685)
- Feat: Configure idle transaction duration (#705)
- Fix: `maxRequestBodySize` should be `never` by default when using the FailedRequestClientAdapter directly (#701)

## 6.3.0-beta.2

- Feat: Improve configuration options of `SentryNavigatorObserver` (#684)
- Feat: Add support for [Dio](https://pub.dev/packages/dio) (#688)
- Bump: Sentry-Android to 5.5.2 and Sentry-Cocoa to 7.8.0 (#696)

## 6.3.0-beta.1

- Enha: Replace flutter default root name '/' with 'root' (#678)
- Fix: Use 'navigation' instead of 'ui.load' for auto transaction operation (#675)
- Fix: Use correct data/extras type in tracer (#693)
- Fix: Do not throw when Throwable type is not supported for associating errors to a transaction (#692)

## 6.3.0-alpha.1

- Feat: Automatically create transactions when navigating between screens (#643)

## 6.2.2

- Fix: ConcurrentModificationError in when finishing span (#664)
- Feat: Add enableNdkScopeSync Android support (#665)

## 6.2.1

- Fix: `sentry_logging` works now on web (#660)
- Fix: `sentry_logging` timestamps are in UTC (#660)
- Fix: `sentry_logging` Level.Off is never recorded (#660)
- Fix: Rate limiting fallback to retryAfterHeader (#658)

## 6.2.0

- Feat: Integration for `logging` (#631)
- Feat: Add logger name to `SentryLogger` and send errors in integrations to the registered logger (#641)

## 6.1.2

- Fix: Remove is Enum check to support older Dart versions (#635)

## 6.1.1

- Fix: Transaction serialization if not encodable (#633)

## 6.1.0

- Bump: Sentry-Android to 5.3.0 and Sentry-Cocoa to 7.5.1 (#629)
- Fix: event.origin tag for macOS and other Apple platforms (#622)
- Feat: Add current route as transaction (#615)
- Feat: Add Breadcrumbs for Flutters `debugPrint` (#618)
- Feat: Enrich Dart context with isolate name (#600)
- Feat: Sentry Performance for HTTP client (#603)
- Performance API for Dart/Flutter (#530)

### Breaking Changes:

- `SentryEvent` inherits from the `SentryEventLike` mixin
- `Scope#transaction` sets and reads from the `Scope#span` object if bound to the Scope

## 6.1.0-beta.1

- Feat: Add current route as transaction (#615)
- Feat: Add Breadcrumbs for Flutters `debugPrint` (#618)

## 6.1.0-alpha.2

- Bump Sentry Android SDK to [5.2.0](https://github.com/getsentry/sentry-dart/pull/594) (#594)
  - [changelog](https://github.com/getsentry/sentry-java/blob/5.2.0/CHANGELOG.md)
  - [diff](https://github.com/getsentry/sentry-java/compare/5.1.2...5.2.0)
- Feat: Enrich Dart context with isolate name (#600)
- Feat: Sentry Performance for HTTP client (#603)

## 6.1.0-alpha.1

- Performance API for Dart/Flutter (#530)

### Breaking Changes:

- `SentryEvent` inherits from the `SentryEventLike` mixin
- `Scope#transaction` sets and reads from the `Scope#span` object if bound to the Scope

## 6.0.1

- Fix: Set custom SentryHttpClientError when HTTP error is captured without an exception (#580)
- Bump: Android AGP 4.1 (#586)
- Bump: Sentry Cocoa to 7.3.0 (#589)

## 6.0.0

- Fix: Update `SentryUser` according to docs (#561)
- Feat: Enable or disable reporting of packages (#563)
- Bump: Sentry-Cocoa to 7.2.7 (#578)
- Bump: Sentry-Android to 5.1.2 (#578)
- Fix: Read Sentry config from environment variables as fallback (#567)

## 6.0.0-beta.4

### Breaking Changes:

- Feat: Lists of exceptions and threads (#524)
- Feat: Collect more information for exceptions collected via `FlutterError.onError` (#538)
- Feat: Add maxAttachmentSize option (#553)
- Feat: HTTP breadcrumbs have the request & response size if available (#552)

## 6.0.0-beta.3

- Fix: Re-initialization of Flutter SDK (#526)
- Enhancement: Call `toString()` on all non-serializable fields (#528)
- Fix: Always call `Flutter.onError` in order to not swallow messages (#533)
- Bump: Android SDK to 5.1.0-beta.6 (#535)

## 6.0.0-beta.2

- Fix: Serialization of Flutter Context (#520)
- Feat: Add support for attachments (#505)
- Feat: Add support for User Feedback (#506)

## 6.0.0-beta.1

- Feat: Browser detection (#502)
- Feat: Enrich events with more context (#452)
- Feat: Add Culture Context (#491)
- Feat: Add DeduplicationEventProcessor (#498)
- Feat: Capture failed requests as event (#473)
- Feat: `beforeSend` callback accepts async code (#494)

### Breaking Changes:

- Ref: EventProcessor changed to an interface (#489)
- Feat: Support envelope based transport for events (#391)
  - The method signature of `Transport` changed from `Future<SentryId> send(SentryEvent event)` to `Future<SentryId> send(SentryEnvelope envelope)`
- Remove `Sentry.currentHub` (#490)
- Ref: Rename `cacheDirSize` to `maxCacheItems` and add `maxCacheItems` for iOS (#495)
- Ref: Add error and stacktrace parameter to logger (#503)
- Feat: Change timespans to Durations in SentryOptions (#504)
- Feat: `beforeSend` callback accepts async code (#494)

### Sentry Self Hosted Compatibility

- Since version `6.0.0` of the `sentry`, [Sentry's version >= v20.6.0](https://github.com/getsentry/self-hosted/releases) is required. This only applies to on-premise Sentry, if you are using sentry.io no action is needed.

## 5.1.0

- Fix: Merge user from event and scope (#467)
- Feature: Allow setting of default values for in-app-frames via `SentryOptions.considerInAppFramesByDefault` (#482)
- Bump: sentry-android to v5.0.1 (#486)
- Bump: Sentry-Cocoa to 7.1.3 for iOS and macOS (#488)

## 5.1.0-beta.1

- Fix: `Sentry.close()` closes native SDK integrations (#388)
- Feat: Support for macOS (#389)
- Feat: Support for Linux (#402)
- Feat: Support for Windows (#407)
- Fix: Mark `Sentry.currentHub` as deprecated (#406)
- Fix: Set console logger as default logger in debug mode (#413)
- Fix: Use name from pubspec.yaml for release if package id is not available (#411)
- Feat: `SentryHttpClient` tracks the duration which a request takes and logs failed requests (#414)
- Bump: sentry-cocoa to v7.0.0 (#424)
- Feat: Support for Out-of-Memory-Tracking on macOS/iOS (#424)
- Fix: Trim `\u0000` from Windows package info (#420)
- Feature: Log calls to `print()` as Breadcrumbs (#439)
- Fix: `dist` was read from `SENTRY_DSN`, now it's read from `SENTRY_DIST` (#442)
- Bump: sentry-cocoa to v7.0.3 (#445)
- Fix: Fix adding integrations on web (#450)
- Fix: Use `log()` instead of `print()` for SDK logging (#453)
- Bump: sentry-android to v5.0.0-beta.2 (#457)
- Feature: Add `withScope` callback to capture methods (#463)
- Fix: Add missing properties `language`, `screenHeightPixels` and `screenWidthPixels` to `SentryDevice` (#465)

### Sentry Self Hosted Compatibility

- This version of the `sentry` Dart package requires [Sentry server >= v20.6.0](https://github.com/getsentry/self-hosted/releases). This only applies to on-premise Sentry, if you are using sentry.io no action is needed.

## 5.0.0

- Sound null safety
- Fix: event.origin and event.environment tags have wrong value for iOS (#365) and (#369)
- Fix: Fix deprecated `registrar.messenger` call in `SentryFlutterWeb` (#364)
- Fix: Enable breadcrumb recording mechanism based on platform (#366)
- Feat: Send default PII options (#360)
- Bump: sentry-cocoa to v6.2.1 (#360)
- Feat: Migration from `package_info` to `package_info_plus` plugin (#370)
- Fix: Set `SentryOptions.debug` in `sentry` (#376)
- Fix: Read all environment variables in `sentry` (#375)

### Breaking Changes:

- Return type of `Sentry.close()` changed from `void` to `Future<void>` and `Integration.close()` changed from `void` to `FutureOr<void>` (#395)
- Remove deprecated member `enableLifecycleBreadcrumbs`. Use `enableAppLifecycleBreadcrumbs` instead. (#366)

## 4.1.0-nullsafety.1

- Bump: sentry-android to v4.3.0 (#343)
- Fix: Multiple FlutterError.onError calls in FlutterErrorIntegration (#345)
- Fix: Pass hint to EventProcessors (#356)
- Fix: EventProcessors were not dropping events when returning null (#353)

### Breaking Changes:

- Fix: Plugin Registrant class moved to barrel file (#358)
  - This changed the import from `import 'package:sentry_flutter/src/sentry_flutter_web.dart';`
    to `import 'package:sentry_flutter/sentry_flutter_web.dart';`
  - This could lead to breaking changes. Typically it shouldn't because the referencing file is auto-generated.
- Fix: Prefix classes with Sentry (#357)
  - A couple of classes were often conflicting with user's code.
    Thus this change renames the following classes:
    - `App` -> `SentryApp`
    - `Browser` -> `SentryBrowser`
    - `Device` -> `SentryDevice`
    - `Gpu` -> `SentryGpu`
    - `Integration` -> `SentryIntegration`
    - `Message` -> `SentryMessage`
    - `OperatingSystem` -> `SentryOperatingSystem`
    - `Request` -> `SentryRequest`
    - `User` -> `SentryUser`
    - `Orientation` -> `SentryOrientation`

## 4.1.0-nullsafety.0

- Fix: Do not append stack trace to the exception if there are no frames
- Fix: Empty DSN disables the SDK and runs the App
- Feat: sentry and sentry_flutter null-safety thanks to @ueman and @fzyzcjy

## 4.0.6

- Fix: captureMessage defaults SentryLevel to info
- Fix: SentryEvent.throwable returns the unwrapped throwable instead of the throwableMechanism
- Feat: Support enableNativeCrashHandling on iOS

## 4.0.5

- Bump: sentry-android to v4.0.0
- Fix: Pana Flutter upper bound deprecation
- Fix: sentry_flutter static analysis (pana) using stable version

## 4.0.4

- Fix: Call WidgetsFlutterBinding.ensureInitialized() within runZoneGuarded

## 4.0.3

- Fix: Auto session tracking start on iOS #274
- Bump: Sentry-cocoa to 6.1.4

## 4.0.2

- Fix: Mark session as `errored` in iOS #270
- Fix: Pass auto session tracking interval to iOS
- Fix: Deprecated binaryMessenger (MethodChannel member) for Flutter Web
- Ref: Make `WidgetsFlutterBinding.ensureInitialized();` the first thing the Sentry SDK calls.
- Bump: Sentry-cocoa to 6.0.12
- Feat: Respect FlutterError silent flag #248
- Bump: Android SDK to v3.2.1 #273

## 4.0.1

- Ref: Changed category of Flutter lifecycle tracking [#240](https://github.com/getsentry/sentry-dart/issues/240)
- Fix: Envelope length should be based on the UTF8 array instead of String length

## 4.0.0

Release of Sentry's new SDK for Dart/Flutter.

New features not offered by <= v4.0.0:

### Dart SDK

- Sentry's [Unified API](https://develop.sentry.dev/sdk/unified-api/).
- Complete Sentry's [Protocol](https://develop.sentry.dev/sdk/event-payloads/) available.
- [Dart SDK](https://docs.sentry.io/platforms/dart/) docs.
- Automatic [HTTP Breadcrumbs](https://docs.sentry.io/platforms/dart/usage/advanced-usage/#automatic-breadcrumbs) for [http.Client](https://pub.dev/documentation/http/latest/http/Client-class.html)
- No boilerplate for `runZonedGuarded` and `Isolate.current.addErrorListener`
- All events are enriched with [Scope's Contexts](https://develop.sentry.dev/sdk/event-payloads/#scope-interfaces), this includes Breadcrumbs, tags, User, etc...

### Flutter SDK

- The Flutter SDK is built on top of the Dart SDK, so it includes all the available features, plus
- [Flutter SDK](https://docs.sentry.io/platforms/flutter/) docs.
- Automatic [NavigatorObserver Breadcrumbs](https://docs.sentry.io/platforms/flutter/usage/advanced-usage/#automatic-breadcrumbs)
- Automatic [Device's Breadcrumbs](https://docs.sentry.io/platforms/flutter/usage/advanced-usage/#automatic-breadcrumbs) through the Android and iOS SDKs or via Sentry's `WidgetsBindingObserver` wrapper
- No boilerplate for `FlutterError.onError`
- All events are enriched with [Contexts's data](https://develop.sentry.dev/sdk/event-payloads/contexts/), this includes Device's, OS, App info, etc...
- Offline caching
- [Release health](https://docs.sentry.io/product/releases/health/)
- Captures not only Dart and Flutter errors, but also errors caused on the native platforms, Like Kotlin, Java, C and C++ for Android and Swift, ObjC, C, C++ for iOS
- Supports Fatal crashes, Event is going to be sent on App's restart
- Supports `split-debug-info` for Android only
- Flutter Android, iOS and limited support for Flutter Web

Improvements:

- Feat: Added a copyWith method to all the protocol classes

Packages were released on [sentry pubdev](https://pub.dev/packages/sentry) and [sentry_flutter pubdev](https://pub.dev/packages/sentry_flutter)

### Sentry Self Hosted Compatibility

- Since version `4.0.0` of the `sentry_flutter`, [Sentry's version >= v20.6.0](https://github.com/getsentry/self-hosted/releases) is required. This only applies to on-premise Sentry, if you are using sentry.io no action is needed.

## 4.0.0-beta.2

- Ref: Remove duplicated attachStackTrace field
- Fix: Flutter Configurations should be able to mutate the SentryFlutterOptions
- Enhancement: Add SentryWidgetsBindingObserver, an Integration that captures certain window and device events.
- Enhancement: Set `options.environment` on SDK init based on the flags (kReleaseMode, kDebugMode, kProfileMode or SENTRY_ENVIRONMENT).
- Feature: SentryHttpClient to capture HTTP requests as breadcrumbs
- Ref: Only assign non-null option values in Android native integration in order preserve default values
- Enhancement: Add 'attachThreads' in options. When enabled, threads are attached to all logged events for Android
- Ref: Rename typedef `Logger` to `SentryLogger` to prevent name clashes with logging packages
- Fix: Scope Event processors should be awaited
- Fix: Package usage as git dependency

### Breaking changes

- `Logger` typedef is renamed to `SentryLogger`
- `attachStackTrace` is renamed to `attachStacktrace`

## 4.0.0-beta.1

- Fix: StackTrace frames with 'package' uri.scheme are inApp by default #185
- Fix: Missing App's StackTrace frames for Flutter errors
- Enhancement: Add isolateErrorIntegration and runZonedGuardedIntegration to default integrations in sentry-dart
- Fix: Breadcrumb list is a plain list instead of a values list #201
- Ref: Remove deprecated classes (Flutter Plugin for Android) and cleaning up #186
- Fix: Handle immutable event lists and maps
- Fix: NDK integration was being disabled by a typo
- Fix: Missing toList for debug meta #192
- Enhancement: NavigationObserver to record Breadcrumbs for navigation events #197
- Fix: Integrations should be closeable
- Feat: Support split-debug-info for Android #191
- Fix: the event payload must never serialize null or empty fields
- Ref: Make hints optional

### Breaking changes

- `Sentry.init` and `SentryFlutter.init` have an optional callback argument which runs the host App after Sentry initialization.
- `Integration` is an `Interface` instead of a pure Function
- `Hints` are optional arguments
- Sentry Dart SDK adds an `IsolateError` handler by default

## 4.0.0-alpha.2

- Enhancement: `Contexts` were added to the `Scope` #154
- Fix: App. would hang if `debug` mode was enabled and refactoring ##157
- Enhancement: Sentry Protocol v7
- Enhancement: Added missing Protocol fields, `Request`, `SentryStackTrace`...) #155
- Feat: Added `attachStackTrace` options to attach stack traces on `captureMessage` calls
- Feat: Flutter SDK has the Native SDKs embedded (Android and Apple) #158

### Breaking changes

- `Sentry.init` returns a `Future`.
- Dart min. SDK is `2.8.0`
- Flutter min. SDK is `1.17.0`
- Timestamp has millis precision.
- For better groupping, add your own package to the `addInAppInclude` list, e.g. `options.addInAppInclude('sentry_flutter_example');`
- A few classes of the `Protocol` were renamed.

### Sentry Self Hosted Compatibility

- Since version `4.0.0` of the `sentry_flutter`, `Sentry` version >= `v20.6.0` is required. This only applies to on-premise Sentry, if you are using sentry.io no action is needed.

## 4.0.0-alpha.1

First Release of Sentry's new SDK for Dart/Flutter.

New features not offered by <= v4.0.0:

- Sentry's [Unified API](https://develop.sentry.dev/sdk/unified-api/).
- Complete Sentry [Protocol](https://develop.sentry.dev/sdk/event-payloads/) available.
- Docs and Migration is under review on this [PR](https://github.com/getsentry/sentry-docs/pull/2599)
- For all the breaking changes follow this [PR](https://github.com/getsentry/sentry-dart/pull/117), they'll be soon available on the Migration page.

Packages were released on [pubdev](https://pub.dev/packages/sentry)

We'd love to get feedback and we'll work in getting the GA 4.0.0 out soon.
Until then, the stable SDK offered by Sentry is at version [3.0.1](https://github.com/getsentry/sentry-dart/releases/tag/3.0.1)

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
