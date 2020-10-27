import 'dart:async';
import 'dart:html';

import 'package:sentry/sentry.dart';

const dsn =
    'https://cb0fad6f5d4e42ebb9c956cb0463edc9@o447951.ingest.sentry.io/5428562';

void main() {
  querySelector('#output').text = 'Your Dart app is running.';

  querySelector('#btEvent')
      .onClick
      .listen((event) => captureCompleteExampleEvent());
  querySelector('#btMessage').onClick.listen((event) => captureMessage());
  querySelector('#btException').onClick.listen((event) => captureException());

  initSentry();
}

void initSentry() {
  Sentry.init((options) => options.dsn = dsn);

  Sentry.addBreadcrumb(
    Breadcrumb(
        message: 'UI Lifecycle',
        timestamp: DateTime.now().toUtc(),
        category: 'ui.lifecycle',
        type: 'navigation',
        data: {'screen': 'MainActivity', 'state': 'created'},
        level: SentryLevel.info),
  );

  Sentry.configureScope((scope) {
    scope
      ..user = User(
        id: '800',
        username: 'first-user',
        email: 'first@user.lan',
        ipAddress: '127.0.0.1',
        extras: <String, String>{'first-sign-in': '2020-01-01'},
      )
      ..fingerprint = ['example-dart']
      ..transaction = '/example/app'
      ..level = SentryLevel.warning
      ..setTag('project-id', '7371')
      ..setExtra('company-name', 'Dart Inc');
  });
}

void captureMessage() async {
  print('Capturing Message :  ');
  final sentryId = await Sentry.captureMessage(
    'Message 2',
    template: 'Message %s',
    params: ['2'],
  );
  print('capture message result : $sentryId');
  if (sentryId != SentryId.empty()) {
    querySelector('#messageResult').style.display = 'block';
  }
  await Sentry.close();
}

void captureException() async {
  try {
    await buildCard();
  } catch (error, stackTrace) {
    print('\nReporting the following stack trace: ');
    print(stackTrace);
    final sentryId = await Sentry.captureException(
      error,
      stackTrace: stackTrace,
    );

    print('Capture exception : SentryId: ${sentryId}');

    if (sentryId != SentryId.empty()) {
      querySelector('#exceptionResult').style.display = 'block';
    }
  }
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

  print('\nReporting a complete event example: ${sdkName}');
  print('Response SentryId: ${sentryId}');

  if (sentryId != SentryId.empty()) {
    querySelector('#eventResult').style.display = 'block';
  }
}

Future<void> buildCard() async {
  await loadData();
}

Future<void> loadData() async {
  await parseData();
}

Future<void> parseData() async {
  throw StateError('This is a test error');
}
