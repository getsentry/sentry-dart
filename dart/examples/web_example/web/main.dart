import 'dart:async';
import 'dart:html';

import 'package:sentry/sentry.dart';

const dsn =
    'https://cb0fad6f5d4e42ebb9c956cb0463edc9@o447951.ingest.sentry.io/5428562';

void main() {
  querySelector('#output').text = 'Your Dart app is running.';

  querySelector('#bt').onClick.listen((event) => capture());

  Sentry.init((options) => options.dsn = dsn);
}

void capture() async {
  print('capture... ');
  //final client = SentryClient(SentryOptions(dsn: dsn));
  await captureCompleteExampleEvent();

  final msgResultId = await Sentry.captureMessage(
    'Message 2',
    template: 'Message %s',
    params: ['2'],
  );
  print('capture message result : $msgResultId');

  try {
    await foo();
  } catch (error, stackTrace) {
    print('\nReporting the following stack trace: ');
    print(stackTrace);
    final response = await Sentry.captureException(
      error,
      stackTrace: stackTrace,
    );

    print('Capture exception : SentryId: ${response}');
  }

  await Sentry.close();
}

Future<void> captureCompleteExampleEvent() async {
  final event = SentryEvent(
    logger: 'main',
    serverName: 'server.dart',
    release: '1.4.0-preview.1',
    environment: 'Test',
    message: Message('This is an example Dart event.'),
    transaction: '/example/app',
    level: SentryLevel.warning,
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
      Breadcrumb(
        message: 'UI Lifecycle',
        timestamp: DateTime.now().toUtc(),
        category: 'ui.lifecycle',
        type: 'navigation',
        data: {'screen': 'MainActivity', 'state': 'created'},
        level: SentryLevel.info,
      )
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
      ),
    ),
  );

  final sentryId = await Sentry.captureEvent(event);

  print(
    '\nReporting a complete event example: ${sdkName}',
  );
  print('Response SentryId: ${sentryId}');
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
