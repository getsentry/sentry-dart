import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app_config.dart';

/// Manual repro harness for
/// https://github.com/getsentry/sentry-dart/issues/3960: on Android, each
/// Activity create/destroy cycle (task removed, process kept alive by a
/// foreground service) permanently retains native/GPU memory when
/// SentryFlutter.init runs in the rendering (UI) isolate — even with this
/// fully-ablated config (no DSN, no native SDK).
///
/// Run with: flutter run -t lib/memleak_repro_main.dart -d <device>
/// (or `flutter build apk --profile -t lib/memleak_repro_main.dart` + adb
/// install, to match the release/profile builds the report used).
///
/// Measure with, before and after each cycle:
///   adb shell dumpsys meminfo io.sentry.flutter.sample
/// (compare the "GL mtrack" and "Native Heap" / "Unknown" lines)
///
/// Repro steps:
///   1. Cold start (tap the launcher icon, or `flutter run`/`adb shell am
///      start`), let it settle, take a meminfo reading.
///   2. Remove the app's task from Recents (the process survives via the
///      foreground service started below).
///   3. Relaunch from the launcher icon (NOT from Recents, so the Activity
///      and its engine are recreated from scratch).
///   4. Repeat 2-3 a few times, taking a meminfo reading after each cycle.
void main() async {
  await SentryFlutter.init((options) {
    options.dsn = '';
    options.autoInitializeNativeSdk = false;
  });

  await execute('start_keep_alive_service');

  runApp(const _MemLeakReproApp());
}

class _MemLeakReproApp extends StatelessWidget {
  const _MemLeakReproApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Mem Leak Repro (#3960)')),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'SentryFlutter.init() has run (dsn empty, '
            'autoInitializeNativeSdk=false) and the keep-alive foreground '
            'service has been started.\n\n'
            'Take a meminfo reading, remove this app from Recents, relaunch '
            'from the launcher icon, and take another reading. See the '
            'doc comment in memleak_repro_main.dart for the full steps.',
          ),
        ),
      ),
    );
  }
}
