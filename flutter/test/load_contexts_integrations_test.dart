import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/sentry_flutter_options.dart';

import 'mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var called = false;

  late Fixture fixture;

  setUp(() {
    fixture = Fixture();

    fixture.channel.setMockMethodCallHandler((MethodCall methodCall) async {
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
    fixture.channel.setMockMethodCallHandler(null);
  });

  SdkVersion getSdkVersion({String name = 'sentry.dart'}) {
    return SdkVersion(
        name: name,
        version: '1.0',
        integrations: const ['EventIntegration'],
        packages: const [SentryPackage('event-package', '2.0')]);
  }

  SentryEvent getEvent({
    SdkVersion? sdk,
    Map<String, String>? tags,
  }) {
    return SentryEvent(
      sdk: sdk ?? getSdkVersion(),
      tags: tags,
    );
  }

  test('$LoadContextsIntegration adds itself to sdk.integrations', () async {
    final integration = fixture.getSut();
    integration(fixture.hub, fixture.options);

    expect(
      fixture.options.sdk.integrations.contains('loadContextsIntegration'),
      true,
    );
  });

  test('should apply the loadContextsIntegration eventProcessor', () async {
    final integration = fixture.getSut();
    integration(fixture.hub, fixture.options);

    expect(fixture.options.eventProcessors.length, 1);

    final e = SentryEvent();
    final event = await (fixture.options.eventProcessors.first(e)
        as FutureOr<SentryEvent>);

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
    final integration = fixture.getSut();
    integration(fixture.hub, fixture.options);

    expect(fixture.options.eventProcessors.length, 1);

    final eventContexts = Contexts(
        device: const SentryDevice(name: 'eDevice'),
        app: const SentryApp(name: 'eApp'),
        operatingSystem: const SentryOperatingSystem(name: 'eOS'),
        gpu: const SentryGpu(name: 'eGpu'),
        browser: const SentryBrowser(name: 'eBrowser'),
        runtimes: [const SentryRuntime(name: 'eRT')])
      ..['theme'] = 'cuppertino';
    final e = SentryEvent(contexts: eventContexts);
    final event = await (fixture.options.eventProcessors.first(e)
        as FutureOr<SentryEvent>);

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
      final integration = fixture.getSut();
      integration(fixture.hub, fixture.options);

      final e = getEvent();
      final event = await (fixture.options.eventProcessors.first(e)
          as FutureOr<SentryEvent>);

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
    fixture.channel.setMockMethodCallHandler((MethodCall methodCall) async {
      throw Exception();
    });
    final integration = fixture.getSut();
    integration(fixture.hub, fixture.options);

    final e = SentryEvent();
    final event = await fixture.options.eventProcessors.first(e);

    expect(event, isNotNull);
  });

  test(
    'should add origin and environment tags if tags is null',
    () async {
      final integration = fixture.getSut();
      integration(fixture.hub, fixture.options);

      final eventSdk = getSdkVersion(name: 'sentry.dart.flutter');
      final e = getEvent(sdk: eventSdk);
      final event = await (fixture.options.eventProcessors.first(e)
          as FutureOr<SentryEvent>);

      expect(event.tags!['event.origin'], 'flutter');
      expect(event.tags!['event.environment'], 'dart');
    },
  );

  test(
    'should merge origin and environment tags',
    () async {
      final integration = fixture.getSut();
      integration(fixture.hub, fixture.options);

      final eventSdk = getSdkVersion(name: 'sentry.dart.flutter');
      final e = getEvent(
        sdk: eventSdk,
        tags: {'a': 'b'},
      );
      final event = await (fixture.options.eventProcessors.first(e)
          as FutureOr<SentryEvent>);

      expect(event.tags!['event.origin'], 'flutter');
      expect(event.tags!['event.environment'], 'dart');
      expect(event.tags!['a'], 'b');
    },
  );

  test(
    'should not add origin and environment tags if not flutter sdk',
    () async {
      final integration = fixture.getSut();
      integration(fixture.hub, fixture.options);

      final e = getEvent(tags: {});
      final event = await (fixture.options.eventProcessors.first(e)
          as FutureOr<SentryEvent>);

      expect(event.tags!.containsKey('event.origin'), false);
      expect(event.tags!.containsKey('event.environment'), false);
    },
  );
}

class Fixture {
  final channel = MethodChannel('sentry_flutter');

  final hub = MockHub();
  final options = SentryFlutterOptions();

  LoadContextsIntegration getSut() {
    return LoadContextsIntegration(channel);
  }
}
