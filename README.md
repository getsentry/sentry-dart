<p align="center">
  <a href="https://sentry.io/?utm_source=github&utm_medium=logo" target="_blank">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-wordmark-dark-280x84.png" alt="Sentry" width="280" height="84">
  </a>
  <a href="https://flutter.dev/docs/development/packages-and-plugins/favorites" target="_blank">
    <img src="https://github.com/getsentry/sentry-dart/raw/main/.github/flutter_favorite.svg" width="100">
  </a>
</p>

_Bad software is everywhere, and we're tired of it. Sentry is on a mission to help developers write better software faster, so we can get back to enjoying technology. If you want to join us [<kbd>**Check out our open positions**</kbd>](https://sentry.io/careers/)_

# Sentry SDK for Dart and Flutter

[![codecov](https://codecov.io/gh/getsentry/sentry-dart/branch/main/graph/badge.svg?token=J0QX0LPmwy)](https://codecov.io/gh/getsentry/sentry-dart)

| Package                                                                                                                            | CI status                                                                                                                                                                        | Likes                                                                                                      | Downloads                                                                                            | Analysis                                                                                                         |
| ---------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| [![sentry](https://img.shields.io/pub/v/sentry.svg?label=sentry)](https://pub.dev/packages/sentry)                                 | [![build](https://github.com/getsentry/sentry-dart/actions/workflows/dart.yml/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions/workflows/dart.yml)       | [![likes](https://img.shields.io/pub/likes/sentry)](https://pub.dev/packages/sentry/score)                 | [![dm](https://img.shields.io/pub/dm/sentry)](https://pub.dev/packages/sentry/score)                 | [![pub points](https://img.shields.io/pub/points/sentry)](https://pub.dev/packages/sentry/score)                 |
| [![sentry_flutter](https://img.shields.io/pub/v/sentry_flutter.svg?label=sentry_flutter)](https://pub.dev/packages/sentry_flutter) | [![build](https://github.com/getsentry/sentry-dart/actions/workflows/flutter.yml/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions/workflows/flutter.yml) | [![likes](https://img.shields.io/pub/likes/sentry_flutter)](https://pub.dev/packages/sentry_flutter/score) | [![dm](https://img.shields.io/pub/dm/sentry_flutter)](https://pub.dev/packages/sentry_flutter/score) | [![pub points](https://img.shields.io/pub/points/sentry_flutter)](https://pub.dev/packages/sentry_flutter/score) |
| [![sentry_logging](https://img.shields.io/pub/v/sentry_logging.svg?label=sentry_logging)](https://pub.dev/packages/sentry_logging) | [![build](https://github.com/getsentry/sentry-dart/actions/workflows/logging.yml/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions/workflows/logging.yml) | [![likes](https://img.shields.io/pub/likes/sentry_logging)](https://pub.dev/packages/sentry_logging/score) | [![dm](https://img.shields.io/pub/dm/sentry_logging)](https://pub.dev/packages/sentry_logging/score) | [![pub points](https://img.shields.io/pub/points/sentry_logging)](https://pub.dev/packages/sentry_logging/score) |
| [![sentry_dio](https://img.shields.io/pub/v/sentry_dio.svg?label=sentry_dio)](https://pub.dev/packages/sentry_dio)                 | [![build](https://github.com/getsentry/sentry-dart/actions/workflows/dio.yml/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions/workflows/dio.yml)         | [![likes](https://img.shields.io/pub/likes/sentry_dio)](https://pub.dev/packages/sentry_dio/score)         | [![dm](https://img.shields.io/pub/dm/sentry_dio)](https://pub.dev/packages/sentry_dio/score)         | [![pub points](https://img.shields.io/pub/points/sentry_dio)](https://pub.dev/packages/sentry_dio/score)         |
| [![sentry_link](https://img.shields.io/pub/v/sentry_link.svg?label=sentry_link)](https://pub.dev/packages/sentry_link)             | [![build](https://github.com/getsentry/sentry-dart/actions/workflows/link.yml/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions/workflows/link.yml)       | [![likes](https://img.shields.io/pub/likes/sentry_link)](https://pub.dev/packages/sentry_link/score)       | [![dm](https://img.shields.io/pub/dm/sentry_link)](https://pub.dev/packages/sentry_link/score)       | [![pub points](https://img.shields.io/pub/points/sentry_link)](https://pub.dev/packages/sentry_link/score)       |
| [![sentry_file](https://img.shields.io/pub/v/sentry_file.svg?label=sentry_file)](https://pub.dev/packages/sentry_file)             | [![build](https://github.com/getsentry/sentry-dart/actions/workflows/file.yml/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions/workflows/file.yml)       | [![likes](https://img.shields.io/pub/likes/sentry_file)](https://pub.dev/packages/sentry_file/score)       | [![dm](https://img.shields.io/pub/dm/sentry_file)](https://pub.dev/packages/sentry_file/score)       | [![pub points](https://img.shields.io/pub/points/sentry_file)](https://pub.dev/packages/sentry_file/score)       |
| [![sentry_sqflite](https://img.shields.io/pub/v/sentry_sqflite.svg?label=sentry_sqflite)](https://pub.dev/packages/sentry_sqflite) | [![build](https://github.com/getsentry/sentry-dart/actions/workflows/sqflite.yml/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions/workflows/sqflite.yml) | [![likes](https://img.shields.io/pub/likes/sentry_sqflite)](https://pub.dev/packages/sentry_sqflite/score) | [![dm](https://img.shields.io/pub/dm/sentry_sqflite)](https://pub.dev/packages/sentry_sqflite/score) | [![pub points](https://img.shields.io/pub/points/sentry_sqflite)](https://pub.dev/packages/sentry_sqflite/score) |
| [![sentry_drift](https://img.shields.io/pub/v/sentry_drift.svg?label=sentry_drift)](https://pub.dev/packages/sentry_drift)         | [![build](https://github.com/getsentry/sentry-dart/actions/workflows/drift.yml/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions/workflows/drift.yml)     | [![likes](https://img.shields.io/pub/likes/sentry_drift)](https://pub.dev/packages/sentry_drift/score)     | [![dm](https://img.shields.io/pub/dm/sentry_drift)](https://pub.dev/packages/sentry_drift/score)     | [![pub points](https://img.shields.io/pub/points/sentry_drift)](https://pub.dev/packages/sentry_drift/score)     |
| [![sentry_hive](https://img.shields.io/pub/v/sentry_hive.svg?label=sentry_hive)](https://pub.dev/packages/sentry_hive)             | [![build](https://github.com/getsentry/sentry-dart/actions/workflows/hive.yml/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions/workflows/hive.yml)       | [![likes](https://img.shields.io/pub/likes/sentry_hive)](https://pub.dev/packages/sentry_hive/score)       | [![dm](https://img.shields.io/pub/dm/sentry_hive)](https://pub.dev/packages/sentry_hive/score)       | [![pub points](https://img.shields.io/pub/points/sentry_hive)](https://pub.dev/packages/sentry_hive/score)       |
| [![sentry_isar](https://img.shields.io/pub/v/sentry_isar.svg?label=sentry_isar)](https://pub.dev/packages/sentry_isar)             | [![build](https://github.com/getsentry/sentry-dart/actions/workflows/isar.yml/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions/workflows/isar.yml)       | [![likes](https://img.shields.io/pub/likes/sentry_isar)](https://pub.dev/packages/sentry_isar/score)       | [![dm](https://img.shields.io/pub/dm/sentry_isar)](https://pub.dev/packages/sentry_isar/score)       | [![pub points](https://img.shields.io/pub/points/sentry_isar)](https://pub.dev/packages/sentry_isar/score)       |

## Releases

This repo uses the following ways to release SDK updates:

- `Pre-release`: We create pre-releases (alpha, beta, RC,…) for larger and potentially more impactful changes, such as new features or major versions.
- `Latest`: We continuously release major/minor/hotfix versions from the `main` branch. These releases go through all our internal quality gates and are very safe to use and intended to be the default for most teams.
- `Stable`: We promote releases from `Latest` when they have been used in the field for some time and in scale, considering time since release, adoption, and other quality and stability metrics. These releases will be indicated on the releases page (https://github.com/getsentry/sentry-dart/releases/) with the `Stable` suffix.

## Usage

For detailed usage, check out the inner [dart](https://github.com/getsentry/sentry-dart/tree/main/packages/dart), [flutter](https://github.com/getsentry/sentry-dart/tree/main/packages/flutter), [logging](https://github.com/getsentry/sentry-dart/tree/main/packages/logging), [dio](https://github.com/getsentry/sentry-dart/tree/main/packages/dio), [file](https://github.com/getsentry/sentry-dart/tree/main/packages/file), [sqflite](https://github.com/getsentry/sentry-dart/tree/main/packages/sqflite), [drift](https://github.com/getsentry/sentry-dart/tree/main/packages/drift), [hive](https://github.com/getsentry/sentry-dart/tree/main/packages/hive) and [isar](https://github.com/getsentry/sentry-dart/tree/main/packages/isar) `README's` or our `Resources` section below.

## Blog posts

[Introducing Mobile Screenshots](https://blog.sentry.io/introducing-mobile-screenshots-and-suspect-commits/).

[With Flutter and Sentry, You Can Put All Your Eggs in One Repo](https://blog.sentry.io/2021/03/03/with-flutter-and-sentry-you-can-put-all-your-eggs-in-one-repo).

[A Sanity Listicle for Mobile Developers](https://blog.sentry.io/2021/03/30/a-sanity-listicle-for-mobile-developers/).

[Supporting Native Android Libraries Loaded From APKs](https://blog.sentry.io/2021/05/13/supporting-native-android-libraries-loaded-from-apks).

## Resources

- [![Flutter docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=flutter%20docs)](https://docs.sentry.io/platforms/flutter/)
- [![Dart docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=dart%20docs)](https://docs.sentry.io/platforms/dart/)
- [![Discussions](https://img.shields.io/github/discussions/getsentry/sentry-dart.svg)](https://github.com/getsentry/sentry-dart/discussions)
- [![Discord Chat](https://img.shields.io/discord/621778831602221064?logo=discord&logoColor=ffffff&color=7389D8)](https://discord.gg/gB6ja9uZuN)
- [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](https://stackoverflow.com/questions/tagged/sentry)
- [![X Follow](https://img.shields.io/twitter/follow/sentry?label=sentry&style=social)](https://x.com/intent/follow?screen_name=sentry)

## Apple Privacy Manifest

Starting with [May 1st 2024](https://developer.apple.com/news/?id=3d8a9yyh), iOS apps are required to declare approved reasons to access certain APIs. This also includes third-party SDKs.
If you are using `sentry-flutter`, update to at least version `7.17.0` to get the updated `sentry-cocoa` native iOS/macOS SDK, supporting the privacy manifest.
All other used dependencies with file declarations are supported by Sentry packages.
Run [flutter pub upgrade](https://docs.flutter.dev/release/upgrade#upgrading-packages) to the latest compatible versions of all the dependencies.

## SDK Size Overhead

The Sentry SDKs for Dart and Flutter typically add approximately 1-1.5 MB to an app’s binary size. The exact impact may vary depending on the device architecture.
