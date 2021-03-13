import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/sentry_flutter_options.dart';

import 'mocks.dart';

void main() {
  const _channel = MethodChannel('sentry_flutter');

  TestWidgetsFlutterBinding.ensureInitialized();

  var called = false;

  setUp(() {
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {
      called = true;
      return {
        'integrations': ['NativeIntegration'],
        'package': {'sdk_name': 'native-package', 'version': '1.0'},
        'contexts': {
          'device': {'name': 'Device1'},
          'app': {'app_name': 'test-app'},
          'os': {'name': 'os1'},
          'gpu': {'name': 'gpu1'},
          'browser': {'name': 'browser1'},
          'runtime': {'name': 'RT1'},
          'theme': 'material',
        }
      };
    });
  });

  tearDown(() {
    _channel.setMockMethodCallHandler(null);
  });

  test('should apply the loadContextsIntegration eventProcessor', () async {
    final options = SentryFlutterOptions()..dsn = fakeDsn;
    final hub = Hub(options);

    LoadContextsIntegration(_channel)(hub, options);

    expect(options.eventProcessors.length, 1);

    final e = SentryEvent();
    final event =
        await (options.eventProcessors.first(e) as FutureOr<SentryEvent>);

    expect(called, true);
    expect(event.contexts.device!.name, 'Device1');
    expect(event.contexts.app!.name, 'test-app');
    expect(event.contexts.operatingSystem!.name, 'os1');
    expect(event.contexts.gpu!.name, 'gpu1');
    expect(event.contexts.browser!.name, 'browser1');
    expect(
        event.contexts.runtimes.any((element) => element.name == 'RT1'), true);
    expect(event.contexts['theme'], 'material');
    expect(
      event.sdk!.packages.any((element) => element.name == 'native-package'),
      true,
    );
    expect(event.sdk!.integrations.contains('NativeIntegration'), true);
  });

  test(
      'should not override event contexts with the loadContextsIntegration infos',
      () async {
    final options = SentryFlutterOptions()..dsn = fakeDsn;
    final hub = Hub(options);

    LoadContextsIntegration(_channel)(hub, options);

    expect(options.eventProcessors.length, 1);

    final eventContexts = Contexts(
        device: const SentryDevice(name: 'eDevice'),
        app: const SentryApp(name: 'eApp'),
        operatingSystem: const OperatingSystem(name: 'eOS'),
        gpu: const Gpu(name: 'eGpu'),
        browser: const SentryBrowser(name: 'eBrowser'),
        runtimes: [const SentryRuntime(name: 'eRT')])
      ..['theme'] = 'cuppertino';
    final e = SentryEvent(contexts: eventContexts);
    final event =
        await (options.eventProcessors.first(e) as FutureOr<SentryEvent>);

    expect(called, true);
    expect(event.contexts.device!.name, 'eDevice');
    expect(event.contexts.app!.name, 'eApp');
    expect(event.contexts.operatingSystem!.name, 'eOS');
    expect(event.contexts.gpu!.name, 'eGpu');
    expect(event.contexts.browser!.name, 'eBrowser');
    expect(
        event.contexts.runtimes.any((element) => element.name == 'RT1'), true);
    expect(
        event.contexts.runtimes.any((element) => element.name == 'eRT'), true);
    expect(event.contexts['theme'], 'cuppertino');
  });

  test(
    'should merge event and loadContextsIntegration sdk packages and integration',
    () async {
      final options = SentryFlutterOptions()..dsn = fakeDsn;
      final hub = Hub(options);

      LoadContextsIntegration(_channel)(hub, options);

      final eventSdk = SdkVersion(
        name: 'sdk1',
        version: '1.0',
        integrations: const ['EventIntegration'],
        packages: const [SentryPackage('event-package', '2.0')],
      );
      final e = SentryEvent(sdk: eventSdk);
      final event =
          await (options.eventProcessors.first(e) as FutureOr<SentryEvent>);

      expect(
        event.sdk!.packages.any((element) => element.name == 'native-package'),
        true,
      );
      expect(
        event.sdk!.packages.any((element) => element.name == 'event-package'),
        true,
      );
      expect(event.sdk!.integrations.contains('NativeIntegration'), true);
      expect(event.sdk!.integrations.contains('EventIntegration'), true);
    },
  );

  test('should not throw on loadContextsIntegration exception', () async {
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {
      throw Exception();
    });
    final options = SentryFlutterOptions()..dsn = fakeDsn;
    final hub = Hub(options);

    LoadContextsIntegration(_channel)(hub, options);

    final e = SentryEvent();
    final event = await options.eventProcessors.first(e);

    expect(event, isNotNull);
  });
}
