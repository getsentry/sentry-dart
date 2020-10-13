import 'package:mockito/mockito.dart';
import 'package:sentry/src/client.dart';
import 'package:sentry/src/protocol.dart';
import 'package:sentry/src/sentry.dart';
import 'package:sentry/src/sentry_options.dart';
import 'package:test/test.dart';

void main() {
  group('Sentry static entry', () {
    SentryClient client;

    Exception anException;

    final dns = 'https://abc@def.ingest.sentry.io/1234567';

    setUp(() {
      Sentry.init(Options(dsn: dns));

      client = MockSentryClient();
      Sentry.initClient(client);
    });

    test('should capture the event', () {
      Sentry.captureEvent(event);
      verify(client.captureEvent(event: event)).called(1);
    });

    test('should capture the event', () {
      Sentry.captureEvent(event);
      verify(client.captureEvent(event: event)).called(1);
    });

    test('should capture the exception', () {
      Sentry.captureException(anException);
      verify(client.captureException(exception: anException)).called(1);
    });
  });
}

class MockSentryClient extends Mock implements SentryClient {}

class Options implements OptionsConfiguration<SentryOptions> {
  final String dsn;

  Options({this.dsn});

  @override
  void configure(SentryOptions options) {
    options.dsn = dsn;
  }
}

final event = Event(
  loggerName: 'main',
  serverName: 'server.dart',
  release: '1.4.0-preview.1',
  environment: 'Test',
  message: Message(formatted: 'This is an example Dart event.'),
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
    ),
  ),
);
