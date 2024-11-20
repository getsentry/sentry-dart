@TestOn('vm')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/load_contexts_integration.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  SdkVersion getSdkVersion({
    String name = 'sentry.dart',
    List<String> integrations = const [],
    List<SentryPackage> packages = const [],
  }) {
    return SdkVersion(
        name: name,
        version: '1.0',
        integrations: integrations,
        packages: packages);
  }

  SentryEvent getEvent({
    SdkVersion? sdk,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    SentryUser? user,
    String? dist,
    String? environment,
    List<String>? fingerprint,
    SentryLevel? level,
    List<Breadcrumb>? breadcrumbs,
    List<String> integrations = const ['EventIntegration'],
    List<SentryPackage> packages = const [
      SentryPackage('event-package', '2.0')
    ],
  }) {
    return SentryEvent(
      sdk: sdk ??
          getSdkVersion(
            integrations: integrations,
            packages: packages,
          ),
      tags: tags,
      // ignore: deprecated_member_use
      extra: extra,
      user: user,
      dist: dist,
      environment: environment,
      fingerprint: fingerprint,
      level: level,
      breadcrumbs: breadcrumbs,
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
    e.contexts.operatingSystem = SentryOperatingSystem(theme: 'theme1');
    e.contexts.app = SentryApp(inForeground: true);

    final event = await fixture.options.eventProcessors.first.apply(e, Hint());

    verify(fixture.binding.loadContexts()).called(1);
    expect(event?.contexts.device?.name, 'Device1');
    expect(event?.contexts.app?.name, 'test-app');
    expect(event?.contexts.app?.inForeground, true);
    expect(event?.contexts.operatingSystem?.name, 'os1');
    expect(event?.contexts.operatingSystem?.theme, 'theme1');
    expect(event?.contexts.gpu?.name, 'gpu1');
    expect(event?.contexts.browser?.name, 'browser1');
    expect(
        event?.contexts.runtimes.any((element) => element.name == 'RT1'), true);
    expect(event?.contexts['theme'], 'material');
    expect(
      event?.sdk?.packages.any((element) => element.name == 'native-package'),
      true,
    );
    expect(event?.sdk?.integrations.contains('NativeIntegration'), true);
    expect(event?.user?.id, '196E065A-AAF7-409A-9A6C-A81F40274CB9');
  });

  test(
      'should not override event contexts with the loadContextsIntegration infos',
      () async {
    final integration = fixture.getSut();
    integration(fixture.hub, fixture.options);

    expect(fixture.options.eventProcessors.length, 1);

    final eventContexts = Contexts(
        device: const SentryDevice(name: 'eDevice'),
        app: const SentryApp(name: 'eApp', inForeground: true),
        operatingSystem: const SentryOperatingSystem(name: 'eOS'),
        gpu: const SentryGpu(name: 'eGpu'),
        browser: const SentryBrowser(name: 'eBrowser'),
        runtimes: [const SentryRuntime(name: 'eRT')])
      ..['theme'] = 'cuppertino';
    final e =
        SentryEvent(contexts: eventContexts, user: SentryUser(id: 'myId'));

    final event = await fixture.options.eventProcessors.first.apply(e, Hint());

    verify(fixture.binding.loadContexts()).called(1);
    expect(event?.contexts.device?.name, 'eDevice');
    expect(event?.contexts.app?.name, 'eApp');
    expect(event?.contexts.app?.inForeground, true);
    expect(event?.contexts.operatingSystem?.name, 'eOS');
    expect(event?.contexts.gpu?.name, 'eGpu');
    expect(event?.contexts.browser?.name, 'eBrowser');
    expect(
        event?.contexts.runtimes.any((element) => element.name == 'RT1'), true);
    expect(
        event?.contexts.runtimes.any((element) => element.name == 'eRT'), true);
    expect(event?.contexts['theme'], 'cuppertino');
    expect(event?.user?.id, 'myId');
  });

  test(
    'should merge event and loadContextsIntegration sdk packages and integration',
    () async {
      final integration = fixture.getSut();
      integration(fixture.hub, fixture.options);

      final e = getEvent();
      final event =
          await fixture.options.eventProcessors.first.apply(e, Hint());

      expect(
        event?.sdk?.packages.any((element) => element.name == 'native-package'),
        true,
      );
      expect(
        event?.sdk?.packages.any((element) => element.name == 'event-package'),
        true,
      );
      expect(event?.sdk?.integrations.contains('NativeIntegration'), true);
      expect(event?.sdk?.integrations.contains('EventIntegration'), true);
    },
  );

  test(
    'should not duplicate integration if already there',
    () async {
      final integration = fixture.getSut(contexts: {
        'integrations': ['EventIntegration']
      });
      integration(fixture.hub, fixture.options);

      final e = getEvent();
      final event =
          await fixture.options.eventProcessors.first.apply(e, Hint());

      expect(
          event?.sdk?.integrations
              .where((element) => element == 'EventIntegration')
              .toList(growable: false)
              .length,
          1);
    },
  );

  test(
    'should not duplicate package if already there',
    () async {
      final integration = fixture.getSut(contexts: {
        'package': {'sdk_name': 'event-package', 'version': '2.0'}
      });
      integration(fixture.hub, fixture.options);

      final e = getEvent();
      final event =
          await fixture.options.eventProcessors.first.apply(e, Hint());

      expect(
          event?.sdk?.packages
              .where((element) =>
                  element.name == 'event-package' && element.version == '2.0')
              .toList(growable: false)
              .length,
          1);
    },
  );

  test(
    'adds package if different version',
    () async {
      final integration = fixture.getSut(contexts: {
        'package': {'sdk_name': 'event-package', 'version': '3.0'}
      });
      integration(fixture.hub, fixture.options);

      final e = getEvent();
      final event =
          await fixture.options.eventProcessors.first.apply(e, Hint());

      expect(
          event?.sdk?.packages
              .where((element) =>
                  element.name == 'event-package' && element.version == '2.0')
              .toList(growable: false)
              .length,
          1);

      expect(
          event?.sdk?.packages
              .where((element) =>
                  element.name == 'event-package' && element.version == '3.0')
              .toList(growable: false)
              .length,
          1);
    },
  );

  test('should not throw on loadContextsIntegration exception', () async {
    when(fixture.binding.loadContexts()).thenThrow(Exception());
    final integration = fixture.getSut();
    integration(fixture.hub, fixture.options);

    final e = SentryEvent();
    final event = await fixture.options.eventProcessors.first.apply(e, Hint());

    expect(event, isNotNull);
  });

  test(
    'should add origin and environment tags if tags is null',
    () async {
      final integration = fixture.getSut();
      integration(fixture.hub, fixture.options);

      final eventSdk = getSdkVersion(name: 'sentry.dart.flutter');
      final e = getEvent(sdk: eventSdk);
      final event =
          await fixture.options.eventProcessors.first.apply(e, Hint());

      expect(event?.tags?['event.origin'], 'flutter');
      expect(event?.tags?['event.environment'], 'dart');
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
      final event =
          await fixture.options.eventProcessors.first.apply(e, Hint());

      expect(event?.tags?['event.origin'], 'flutter');
      expect(event?.tags?['event.environment'], 'dart');
      expect(event?.tags?['a'], 'b');
    },
  );

  test(
    'should not add origin and environment tags if not flutter sdk',
    () async {
      final integration = fixture.getSut();
      integration(fixture.hub, fixture.options);

      final e = getEvent(tags: {});
      final event =
          await fixture.options.eventProcessors.first.apply(e, Hint());

      expect(event?.tags?.containsKey('event.origin'), false);
      expect(event?.tags?.containsKey('event.environment'), false);
    },
  );

  test('should merge in tags from native without overriding flutter keys',
      () async {
    final integration = fixture.getSut();
    integration(fixture.hub, fixture.options);

    final e = getEvent(tags: {'key': 'flutter', 'key-a': 'flutter'});
    final event = await fixture.options.eventProcessors.first.apply(e, Hint());

    expect(event?.tags?['key'], 'flutter');
    expect(event?.tags?['key-a'], 'flutter');
    expect(event?.tags?['key-b'], 'native');
  });

  test('should merge in extra from native without overriding flutter keys',
      () async {
    final integration = fixture.getSut();
    integration(fixture.hub, fixture.options);

    final e = getEvent(extra: {'key': 'flutter', 'key-a': 'flutter'});
    final event = await fixture.options.eventProcessors.first.apply(e, Hint());

    // ignore: deprecated_member_use
    expect(event?.extra?['key'], 'flutter');
    // ignore: deprecated_member_use
    expect(event?.extra?['key-a'], 'flutter');
    // ignore: deprecated_member_use
    expect(event?.extra?['key-b'], 'native');
  });

  test('should set user from native', () async {
    final integration = fixture.getSut();
    integration(fixture.hub, fixture.options);

    final e = getEvent();
    final event = await fixture.options.eventProcessors.first.apply(e, Hint());

    expect(event?.user?.id, '196E065A-AAF7-409A-9A6C-A81F40274CB9');
    expect(event?.user?.username, 'fixture-username');
    expect(event?.user?.email, 'fixture-email');
    expect(event?.user?.ipAddress, 'fixture-ip_address');
    expect(event?.user?.data?['key'], 'value');
  });

  test('should not override user with native', () async {
    final integration = fixture.getSut();
    integration(fixture.hub, fixture.options);

    final e = getEvent(user: SentryUser(id: 'abc'));
    final event = await fixture.options.eventProcessors.first.apply(e, Hint());

    expect(event?.user?.id, 'abc');
  });

  test('should set dist from native', () async {
    final integration = fixture.getSut();
    integration(fixture.hub, fixture.options);

    final e = getEvent();
    final event = await fixture.options.eventProcessors.first.apply(e, Hint());

    expect(event?.dist, 'fixture-dist');
  });

  test('should not override dist with native', () async {
    final integration = fixture.getSut();
    integration(fixture.hub, fixture.options);

    final e = getEvent(dist: 'abc');
    final event = await fixture.options.eventProcessors.first.apply(e, Hint());

    expect(event?.dist, 'abc');
  });

  test('should set environment from native', () async {
    final integration = fixture.getSut();
    integration(fixture.hub, fixture.options);

    final e = getEvent();
    final event = await fixture.options.eventProcessors.first.apply(e, Hint());

    expect(event?.environment, 'fixture-environment');
  });

  test('should not override environment with native', () async {
    final integration = fixture.getSut();
    integration(fixture.hub, fixture.options);

    final e = getEvent(environment: 'abc');
    final event = await fixture.options.eventProcessors.first.apply(e, Hint());

    expect(event?.environment, 'abc');
  });

  test('should merge in fingerprint from native without duplicating entries',
      () async {
    final integration = fixture.getSut();
    integration(fixture.hub, fixture.options);

    final e = getEvent(fingerprint: ['fingerprint-a', 'fingerprint-b']);
    final event = await fixture.options.eventProcessors.first.apply(e, Hint());

    expect(event?.fingerprint, ['fingerprint-a', 'fingerprint-b']);
  });

  test('should set level from native', () async {
    final integration = fixture.getSut();
    integration(fixture.hub, fixture.options);

    final e = getEvent();
    final event = await fixture.options.eventProcessors.first.apply(e, Hint());

    expect(event?.level, SentryLevel.error);
  });

  test('should not override level with native', () async {
    final integration = fixture.getSut();
    integration(fixture.hub, fixture.options);

    final e = getEvent(level: SentryLevel.fatal);
    final event = await fixture.options.eventProcessors.first.apply(e, Hint());

    expect(event?.level, SentryLevel.fatal);
  });
}

class Fixture {
  final hub = MockHub();
  final options = defaultTestOptions();
  final binding = MockSentryNativeBinding();

  LoadContextsIntegration getSut(
      {Map<String, dynamic> contexts = const {
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
        },
        'user': {
          'id': '196E065A-AAF7-409A-9A6C-A81F40274CB9',
          'username': 'fixture-username',
          'email': 'fixture-email',
          'ip_address': 'fixture-ip_address',
          'data': {'key': 'value'},
        },
        'tags': {'key-a': 'native', 'key-b': 'native'},
        'extra': {'key-a': 'native', 'key-b': 'native'},
        'dist': 'fixture-dist',
        'environment': 'fixture-environment',
        'fingerprint': ['fingerprint-a'],
        'level': 'error',
        'breadcrumbs': [
          <String, dynamic>{
            'timestamp': '1970-01-01T00:00:00.000Z',
            'message': 'native-crumb',
          }
        ]
      }}) {
    when(binding.loadContexts()).thenAnswer((_) async => contexts);
    return LoadContextsIntegration(binding);
  }
}
