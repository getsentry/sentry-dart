// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:sentry/sentry.dart';

/// Sends a test exception report to Sentry.io using this Dart client.
Future<void> main(List<String> rawArgs) async {
  if (rawArgs.length != 1) {
    stderr.writeln(
        'Expected exactly one argument, which is the DSN issued by Sentry.io to your project.');
    exit(1);
  }

  final dsn = rawArgs.single;
  final client = SentryClient(dsn: dsn);

  // Sends a full Sentry event payload to show the different parts of the UI.
  await captureCompleteExampleEvent(client);

  try {
    await foo();
  } catch (error, stackTrace) {
    print('\nReporting the following stack trace: ');
    print(stackTrace);
    final response = await client.captureException(
      exception: error,
      stackTrace: stackTrace,
    );

    if (response.isSuccessful) {
      print('SUCCESS\nid: ${response.eventId}');
    } else {
      print('FAILURE: ${response.error}');
    }
  } finally {
    await client.close();
  }
}

Future<void> captureCompleteExampleEvent(SentryClient client) async {
  final event = Event(
      loggerName: 'main',
      serverName: 'server.dart',
      release: '1.4.0-preview.1',
      environment: 'Test',
      message: 'This is an example Dart event.',
      transaction: '/example/app',
      level: SeverityLevel.warning,
      tags: const <String, String>{'project-id': '7371'},
      extra: const <String, String>{'company-name': 'Dart Inc'},
      fingerprint: const <String>['example-dart'],
      userContext: const User(
          id: '800',
          username: 'first-user',
          email: 'first@user.lan',
          ipAddress: '127.0.0.1',
          extras: <String, String>{'first-sign-in': '2020-01-01'}),
      breadcrumbs: [
        Breadcrumb('UI Lifecycle', DateTime.now().toUtc(),
            category: 'ui.lifecycle',
            type: 'navigation',
            data: {'screen': 'MainActivity', 'state': 'created'},
            level: SeverityLevel.info)
      ],
      contexts: Contexts(
          operatingSystem: const OperatingSystem(
              name: 'Android',
              version: '5.0.2',
              build: 'LRX22G.P900XXS0BPL2',
              kernelVersion:
                  'Linux version 3.4.39-5726670 (dpi@SWHC3807) (gcc version 4.8 (GCC) ) #1 SMP PREEMPT Thu Dec 1 19:42:39 KST 2016',
              rooted: false),
          runtimes: [const Runtime(name: 'ART', version: '5')],
          app: App(
              name: 'Example Dart App',
              version: '1.42.0',
              identifier: 'HGT-App-13',
              build: '93785',
              buildType: 'release',
              deviceAppHash: '5afd3a6',
              startTime: DateTime.now().toUtc()),
          browser: const Browser(name: 'Firefox', version: '42.0.1'),
          device: Device(
            name: 'SM-P900',
            family: 'SM-P900',
            model: 'SM-P900 (LRX22G)',
            modelId: 'LRX22G',
            arch: 'armeabi-v7a',
            batteryLevel: 99,
            orientation: Orientation.landscape,
            manufacturer: 'samsung',
            brand: 'samsung',
            screenResolution: '2560x1600',
            screenDensity: 2.1,
            screenDpi: 320,
            online: true,
            charging: true,
            lowMemory: true,
            simulator: false,
            memorySize: 1500,
            freeMemory: 200,
            usableMemory: 4294967296,
            storageSize: 4294967296,
            freeStorage: 2147483648,
            externalStorageSize: 8589934592,
            externalFreeStorage: 2863311530,
            bootTime: DateTime.now().toUtc(),
            timezone: 'America/Toronto',
          )));

  final response = await client.captureEvent(event: event);

  print('\nReporting a complete event example: ');
  if (response.isSuccessful) {
    print('SUCCESS\nid: ${response.eventId}');
  } else {
    print('FAILURE: ${response.error}');
  }
}

Future<void> foo() async {
  await bar();
}

Future<void> bar() async {
  await baz();
}

Future<void> baz() async {
  throw StateError('This is a test error');
}
