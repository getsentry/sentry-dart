<p align="center">
  <a href="https://sentry.io/?utm_source=github&utm_medium=logo" target="_blank">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-wordmark-dark-280x84.png" alt="Sentry" width="280" height="84">
  </a>
  <a href="https://flutter.dev/docs/development/packages-and-plugins/favorites" target="_blank">
    <img src="https://github.com/getsentry/sentry-dart/raw/main/.github/flutter_favorite.svg" width="100">
  </a>
</p>

_Bad software is everywhere, and we're tired of it. Sentry is on a mission to help developers write better software faster, so we can get back to enjoying technology. If you want to join us [<kbd>**Check out our open positions**</kbd>](https://sentry.io/careers/)_

Sentry SDK for Dart and Flutter
===========

[![codecov](https://codecov.io/gh/getsentry/sentry-dart/branch/main/graph/badge.svg?token=J0QX0LPmwy)](https://codecov.io/gh/getsentry/sentry-dart)

| package        | build                                                                                                                                                                                 | pub                                                                                                        | likes                                                                                                                | popularity | pub points |
|----------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------| ------- | ------- |
| sentry         | [![build](https://github.com/getsentry/sentry-dart/actions/workflows/dart.yml/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-dart)       | [![pub package](https://img.shields.io/pub/v/sentry.svg)](https://pub.dev/packages/sentry)                 | [![likes](https://img.shields.io/pub/likes/sentry?logo=dart)](https://pub.dev/packages/sentry/score)                 | [![popularity](https://img.shields.io/pub/popularity/sentry?logo=dart)](https://pub.dev/packages/sentry/score) | [![pub points](https://img.shields.io/pub/points/sentry?logo=dart)](https://pub.dev/packages/sentry/score)
| sentry_flutter | [![build](https://github.com/getsentry/sentry-dart/workflows/sentry-flutter/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-flutter) | [![pub package](https://img.shields.io/pub/v/sentry_flutter.svg)](https://pub.dev/packages/sentry_flutter) | [![likes](https://img.shields.io/pub/likes/sentry_flutter?logo=dart)](https://pub.dev/packages/sentry_flutter/score) | [![popularity](https://img.shields.io/pub/popularity/sentry_flutter?logo=dart)](https://pub.dev/packages/sentry_flutter/score) | [![pub points](https://img.shields.io/pub/points/sentry_flutter?logo=dart)](https://pub.dev/packages/sentry_flutter/score)
| sentry_logging | [![build](https://github.com/getsentry/sentry-dart/workflows/sentry-logging/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Alogging)        | [![pub package](https://img.shields.io/pub/v/sentry_logging.svg)](https://pub.dev/packages/sentry_logging) | [![likes](https://img.shields.io/pub/likes/sentry_logging?logo=dart)](https://pub.dev/packages/sentry_logging/score) | [![popularity](https://img.shields.io/pub/popularity/sentry_logging?logo=dart)](https://pub.dev/packages/sentry_logging/score) | [![pub points](https://img.shields.io/pub/points/sentry_logging?logo=dart)](https://pub.dev/packages/sentry_logging/score)
| sentry_dio     | [![build](https://github.com/getsentry/sentry-dart/workflows/sentry-dio/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-dio)         | [![pub package](https://img.shields.io/pub/v/sentry_dio.svg)](https://pub.dev/packages/sentry_dio)         | [![likes](https://img.shields.io/pub/likes/sentry_dio?logo=dart)](https://pub.dev/packages/sentry_dio/score)         | [![popularity](https://img.shields.io/pub/popularity/sentry_dio?logo=dart)](https://pub.dev/packages/sentry_dio/score) | [![pub points](https://img.shields.io/pub/points/sentry_dio?logo=dart)](https://pub.dev/packages/sentry_dio/score)
| sentry_file    | [![build](https://github.com/getsentry/sentry-dart/workflows/sentry-file/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-file)       | [![pub package](https://img.shields.io/pub/v/sentry_file.svg)](https://pub.dev/packages/sentry_file)       | [![likes](https://img.shields.io/pub/likes/sentry_file?logo=dart)](https://pub.dev/packages/sentry_file/score)       | [![popularity](https://img.shields.io/pub/popularity/sentry_file?logo=dart)](https://pub.dev/packages/sentry_file/score) | [![pub points](https://img.shields.io/pub/points/sentry_file?logo=dart)](https://pub.dev/packages/sentry_file/score)
| sentry_sqflite | [![build](https://github.com/getsentry/sentry-dart/workflows/sentry-sqflite/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-sqflite) | [![pub package](https://img.shields.io/pub/v/sentry_sqflite.svg)](https://pub.dev/packages/sentry_sqflite) | [![likes](https://img.shields.io/pub/likes/sentry_sqflite)](https://pub.dev/packages/sentry_sqflite/score)           | [![popularity](https://img.shields.io/pub/popularity/sentry_sqflite)](https://pub.dev/packages/sentry_sqflite/score) | [![pub points](https://img.shields.io/pub/points/sentry_sqflite)](https://pub.dev/packages/sentry_sqflite/score)
| sentry_drift   | [![build](https://github.com/getsentry/sentry-dart/actions/workflows/drift.yml/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-drift)     | [![pub package](https://img.shields.io/pub/v/sentry_drift.svg)](https://pub.dev/packages/sentry_drift)     | [![likes](https://img.shields.io/pub/likes/sentry_drift)](https://pub.dev/packages/sentry_drift/score)             | [![popularity](https://img.shields.io/pub/popularity/sentry_drift)](https://pub.dev/packages/sentry_drift/score) | [![pub points](https://img.shields.io/pub/points/sentry_drift)](https://pub.dev/packages/sentry_drift/score)
| sentry_hive | [![build](https://github.com/getsentry/sentry-dart/actions/workflows/hive.yml/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-hive) | [![pub package](https://img.shields.io/pub/v/sentry_hive.svg)](https://pub.dev/packages/sentry_hive) | [![likes](https://img.shields.io/pub/likes/sentry_hive)](https://pub.dev/packages/sentry_hive/score)           | [![popularity](https://img.shields.io/pub/popularity/sentry_hive)](https://pub.dev/packages/sentry_hive/score) | [![pub points](https://img.shields.io/pub/points/sentry_hive)](https://pub.dev/packages/sentry_hive/score)
| sentry_isar | [![build](https://github.com/getsentry/sentry-dart/actions/workflows/isar.yml/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-isar) | [![pub package](https://img.shields.io/pub/v/sentry_isar.svg)](https://pub.dev/packages/sentry_isar) | [![likes](https://img.shields.io/pub/likes/sentry_isar)](https://pub.dev/packages/sentry_isar/score) | [![popularity](https://img.shields.io/pub/popularity/sentry_isar)](https://pub.dev/packages/sentry_isar/score) | [![pub points](https://img.shields.io/pub/points/sentry_isar)](https://pub.dev/packages/sentry_isar/score)

##### Usage

For detailed usage, check out the inner [dart](https://github.com/getsentry/sentry-dart/tree/main/dart), [flutter](https://github.com/getsentry/sentry-dart/tree/main/flutter), [logging](https://github.com/getsentry/sentry-dart/tree/main/logging), [dio](https://github.com/getsentry/sentry-dart/tree/main/dio), [file](https://github.com/getsentry/sentry-dart/tree/main/file), [sqflite](https://github.com/getsentry/sentry-dart/tree/main/sqflite), [drift](https://github.com/getsentry/sentry-dart/tree/main/drift), [hive](https://github.com/getsentry/sentry-dart/tree/main/hive) and [isar](https://github.com/getsentry/sentry-dart/tree/main/isar) `README's` or our `Resources` section below.

#### Blog posts

[Introducing Mobile Screenshots](https://blog.sentry.io/introducing-mobile-screenshots-and-suspect-commits/).

[With Flutter and Sentry, You Can Put All Your Eggs in One Repo](https://blog.sentry.io/2021/03/03/with-flutter-and-sentry-you-can-put-all-your-eggs-in-one-repo).

[A Sanity Listicle for Mobile Developers](https://blog.sentry.io/2021/03/30/a-sanity-listicle-for-mobile-developers/).

[Supporting Native Android Libraries Loaded From APKs](https://blog.sentry.io/2021/05/13/supporting-native-android-libraries-loaded-from-apks).

#### Resources

* [![Flutter docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=flutter%20docs)](https://docs.sentry.io/platforms/flutter/)
* [![Dart docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=dart%20docs)](https://docs.sentry.io/platforms/dart/)
* [![Discussions](https://img.shields.io/github/discussions/getsentry/sentry-dart.svg)](https://github.com/getsentry/sentry-dart/discussions)
* [![Discord Chat](https://img.shields.io/discord/621778831602221064?logo=discord&logoColor=ffffff&color=7389D8)](https://discord.gg/PXa5Apfe7K)  
* [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](https://stackoverflow.com/questions/tagged/sentry)
* [![Twitter Follow](https://img.shields.io/twitter/follow/getsentry?label=getsentry&style=social)](https://twitter.com/intent/follow?screen_name=getsentry)

#### Apple Privacy Manifest

Starting with [May 1st 2024](https://developer.apple.com/news/?id=3d8a9yyh), iOS apps are required to declare approved reasons to access certain APIs. This also includes third-party SDKs.
If you are using `sentry-flutter`, update to at least version `7.17.0` to get the updated `sentry-cocoa` native iOS/macOS SDK, supporting the privacy manifest.
All other used dependencies with file declarations are supported by Sentry packages.
Run [flutter pub upgrade](https://docs.flutter.dev/release/upgrade#upgrading-packages) to the latest compatible versions of all the dependencies.
