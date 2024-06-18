# Changelog

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
