import 'package:sentry/sentry.dart';
import 'package:sentry/src/transport/rate_limiter.dart';

final fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

SentryOptions defaultTestOptions() {
  // ignore: invalid_use_of_internal_member
  return SentryOptions(dsn: fakeDsn)..automatedTestMode = true;
}

final fakeException = Exception('Error');

final fakeMessage = SentryMessage(
  'message 1',
  template: 'message %d',
  params: <dynamic>['1'],
);

final fakeUser = SentryUser(id: '1', email: 'test@test');

final fakeEvent = SentryEvent(
  logger: 'main',
  serverName: 'server.dart',
  release: '1.4.0-preview.1',
  environment: 'Test',
  message: SentryMessage('This is an example Dart event.'),
  transaction: '/example/app',
  level: SentryLevel.warning,
  tags: const <String, String>{'project-id': '7371'},
  // ignore: deprecated_member_use
  extra: const <String, String>{'company-name': 'Dart Inc'},
  fingerprint: const <String>['example-dart'],
  modules: const {'module1': 'factory'},
  sdk: SdkVersion(name: 'sdk1', version: '1.0.0'),
  user: SentryUser(
    id: '800',
    username: 'first-user',
    email: 'first@user.lan',
    ipAddress: '127.0.0.1',
    data: <String, String>{'first-sign-in': '2020-01-01'},
  ),
  breadcrumbs: [
    Breadcrumb(
      message: 'UI Lifecycle',
      timestamp: DateTime.now().toUtc(),
      category: 'ui.lifecycle',
      type: 'navigation',
      data: <String, dynamic>{'screen': 'MainActivity', 'state': 'created'},
      level: SentryLevel.info,
    ),
  ],
  contexts: Contexts(
    operatingSystem: const SentryOperatingSystem(
      name: 'Android',
      version: '5.0.2',
      build: 'LRX22G.P900XXS0BPL2',
      kernelVersion:
          'Linux version 3.4.39-5726670 (dpi@SWHC3807) (gcc version 4.8 (GCC) ) #1 SMP PREEMPT Thu Dec 1 19:42:39 KST 2016',
      rooted: false,
    ),
    runtimes: [const SentryRuntime(name: 'ART', version: '5')],
    app: SentryApp(
      name: 'Example Dart App',
      version: '1.42.0',
      identifier: 'HGT-App-13',
      build: '93785',
      buildType: 'release',
      deviceAppHash: '5afd3a6',
      startTime: DateTime.now().toUtc(),
    ),
    browser: const SentryBrowser(
      name: 'Firefox',
      version: '42.0.1',
    ),
    device: SentryDevice(
      name: 'SM-P900',
      family: 'SM-P900',
      model: 'SM-P900 (LRX22G)',
      modelId: 'LRX22G',
      arch: 'armeabi-v7a',
      batteryLevel: 99,
      orientation: SentryOrientation.landscape,
      manufacturer: 'samsung',
      brand: 'samsung',
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
    ),
  ),
);

/// Doesn't do anything with the events
class NoOpEventProcessor implements EventProcessor {
  @override
  SentryEvent? apply(SentryEvent event, Hint hint) {
    return event;
  }
}

/// Always returns null and thus drops all events
class DropAllEventProcessor implements EventProcessor {
  @override
  SentryEvent? apply(SentryEvent event, Hint hint) {
    return null;
  }
}

class FunctionEventProcessor implements EventProcessor {
  FunctionEventProcessor(this.applyFunction);

  final EventProcessorFunction applyFunction;

  @override
  SentryEvent? apply(SentryEvent event, Hint hint) {
    return applyFunction(event, hint);
  }
}

typedef EventProcessorFunction = SentryEvent? Function(
  SentryEvent event,
  Hint hint,
);

var fakeEnvelope = SentryEnvelope.fromEvent(
  fakeEvent,
  SdkVersion(name: 'sdk1', version: '1.0.0'),
  dsn: fakeDsn,
);

class MockRateLimiter implements RateLimiter {
  bool filterReturnsNull = false;
  SentryEnvelope? filteredEnvelope;
  SentryEnvelope? envelopeToFilter;

  String? sentryRateLimitHeader;
  String? retryAfterHeader;
  int? errorCode;

  @override
  SentryEnvelope? filter(SentryEnvelope envelope) {
    if (filterReturnsNull) {
      return null;
    }
    envelopeToFilter = envelope;
    return filteredEnvelope ?? envelope;
  }

  @override
  void updateRetryAfterLimits(
    String? sentryRateLimitHeader,
    String? retryAfterHeader,
    int errorCode,
  ) {
    this.sentryRateLimitHeader = sentryRateLimitHeader;
    this.retryAfterHeader = retryAfterHeader;
    this.errorCode = errorCode;
  }
}
