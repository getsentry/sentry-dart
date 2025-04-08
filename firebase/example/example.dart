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
        featureFlagKeys: {'firebase_feature_flag_a', 'firebase_feature_flag_b'},
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
