import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app_config.dart' as config;

const _channel = MethodChannel('example.flutter.sentry.io');
const _release = 'flutter-ios-profile@testflight.1';

int mixProfilePixels(int value) {
  for (var i = 0; i < 32000; i++) {
    value = ((value * 1664525 + 1013904223) ^ (value >> 8)) & 0x7fffffff;
  }
  return value;
}

int scoreProfileTile(int seed) => mixProfilePixels(seed) ^ 0x2468;

int buildProfileBatch(int seed) => scoreProfileTile(seed) ^ 0x1357;

Future<int> _work() async {
  final clock = Stopwatch()..start();
  var seed = 42;
  while (clock.elapsed < const Duration(seconds: 18)) {
    for (var i = 0; i < 24; i++) {
      seed = buildProfileBatch(seed);
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  return seed;
}

Future<void> main() async {
  final status = ValueNotifier('Starting the CPU profile…');
  await SentryFlutter.init(
    (options) {
      options.dsn = config.exampleDsn;
      options.release = _release;
      options.environment = 'ios-cocoa-profile-demo';
    },
    appRunner: () => runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ValueListenableBuilder<String>(
                valueListenable: status,
                builder: (_, message, _) =>
                    Text(message, textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await _channel.invokeMethod<void>('startProfileProbe');
  try {
    status.value = 'Profiling the main isolate. Keep the app open.';
    final mainChecksum = await _work();
    status.value = 'Profiling the worker isolate. Keep the app open.';
    final workerChecksum = await Isolate.run(_work, debugName: 'profile-tiles');
    debugPrint('Cocoa AOT checksums $mainChecksum $workerChecksum');
  } finally {
    await _channel.invokeMethod<void>('stopProfileProbe');
  }
  status.value = 'Workload finished. Keep the app open for the profile upload.';
  await Future<void>.delayed(const Duration(seconds: 35));
  status.value = 'Profile run complete. You can close the app.';
}
