<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>


===========

<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

Sentry integration for `firebase_remote_config` package
===========

| package     | build                                                                                                                                                                                | pub                                                                                                  | likes                                                                                                | popularity                                                                                                     | pub points |
|-------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------| ------- |
| sentry_firebase_remote_config | [![build](https://github.com/getsentry/sentry-dart/actions/workflows/firebase.yml/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-firebase) | [![pub package](https://img.shields.io/pub/v/sentry_firebase_remote_config.svg)](https://pub.dev/packages/sentry_firebase_remote_config) | [![likes](https://img.shields.io/pub/likes/sentry_firebase_remote_config)](https://pub.dev/packages/sentry_firebase_remote_config/score) | [![popularity](https://img.shields.io/pub/popularity/sentry_firebase_remote_config)](https://pub.dev/packages/sentry_firebase_remote_config/score) | [![pub points](https://img.shields.io/pub/points/sentry_firebase_remote_config)](https://pub.dev/packages/sentry_firebase_remote_config/score)

Integration for [`firebase_remote_config`](https://pub.dev/packages/firebase_remote_config) package. Track changes to firebase boolean values as feature flags in Sentry.io

#### Usage

- Sign up for a Sentry.io account and get a DSN at https://sentry.io.

- Follow the installing instructions on [pub.dev](https://pub.dev/packages/sentry/install).

- Initialize the Sentry SDK using the DSN issued by Sentry.io.

- Call...

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config_example/home_page.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_firebase_remote_config/sentry_firebase_remote_config.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final remoteConfig = FirebaseRemoteConfig.instance;
  await remoteConfig.setConfigSettings(RemoteConfigSettings(
    fetchTimeout: const Duration(minutes: 1),
    minimumFetchInterval: const Duration(hours: 1),
  ));

  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://example@sentry.io/add-your-dsn-here';

      final sentryFirebaseRemoteConfigIntegration = SentryFirebaseRemoteConfigIntegration(
        firebaseRemoteConfig: remoteConfig,
        // Don't call `await remoteConfig.activate();` when firebase config is updated. Per default this is true.
        activateOnConfigUpdated: false,
      );
      options.addIntegration(sentryFirebaseRemoteConfigIntegration);
    },
  );

  runApp(const RemoteConfigApp());
}

class RemoteConfigApp extends StatelessWidget {
  const RemoteConfigApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remote Config Example',
      home: const HomePage(),
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
      ),
    );
  }
}
```

#### Resources

* [![Flutter docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=flutter%20docs)](https://docs.sentry.io/platforms/flutter/)
* [![Dart docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=dart%20docs)](https://docs.sentry.io/platforms/dart/)
* [![Discussions](https://img.shields.io/github/discussions/getsentry/sentry-dart.svg)](https://github.com/getsentry/sentry-dart/discussions)
* [![Discord Chat](https://img.shields.io/discord/621778831602221064?logo=discord&logoColor=ffffff&color=7389D8)](https://discord.gg/gB6ja9uZuN)
* [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](https://stackoverflow.com/questions/tagged/sentry)
* [![Twitter Follow](https://img.shields.io/twitter/follow/getsentry?label=getsentry&style=social)](https://twitter.com/intent/follow?screen_name=getsentry)
