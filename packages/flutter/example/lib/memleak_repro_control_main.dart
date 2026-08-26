import 'package:flutter/material.dart';

import 'app_config.dart';

/// Control variant of memleak_repro_main.dart for
/// https://github.com/getsentry/sentry-dart/issues/3960: identical harness
/// (same foreground service, same UI, same repro steps) but never calls
/// SentryFlutter.init() at all, to measure the "natural" native/GPU memory
/// growth from Activity/engine recreation alone, with no Sentry code
/// running - a baseline to compare the sentry_flutter numbers against.
///
/// Run with: flutter run -t lib/memleak_repro_control_main.dart -d <device>
/// (or `flutter build apk --profile -t lib/memleak_repro_control_main.dart`
/// + adb install).
///
/// Measure with, before and after each cycle:
///   adb shell dumpsys meminfo io.sentry.flutter.sample
/// (compare the "GL mtrack" and "Native Heap" / "Unknown" lines)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await execute('start_keep_alive_service');

  runApp(const _MemLeakReproControlApp());
}

class _MemLeakReproControlApp extends StatelessWidget {
  const _MemLeakReproControlApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Mem Leak Repro Control (no Sentry)')),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'SentryFlutter.init() was NEVER called. Only the keep-alive '
            'foreground service has been started.\n\n'
            'Take a meminfo reading, remove this app from Recents, relaunch '
            'from the launcher icon, and take another reading.',
          ),
        ),
      ),
    );
  }
}
