@TestOn('vm')
library;

// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/load_contexts_integration.dart';

import 'fixture.dart';

void main() {
  final defaultContexts = {
    'integrations': ['NativeIntegration'],
    'package': {'sdk_name': 'native-package', 'version': '1.0'},
    'contexts': {
      'device': {
        'name': 'Device1',
        'family': 'fixture-device-family',
        'model': 'fixture-device-model',
        'brand': 'fixture-device-brand',
      },
      'app': {'app_name': 'test-app'},
      'os': {
        'name': 'fixture-os-name',
        'version': 'fixture-os-version',
      },
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
  };

  SentryLog givenLog() {
    return SentryLog(
      timestamp: DateTime.now(),
      traceId: SentryId.newId(),
      level: SentryLogLevel.info,
      body: 'test',
      attributes: {
        'attribute': SentryAttribute.string('value'),
      },
    );
  }

  SdkVersion getSdkVersion({
    String name = 'sentry.dart',
    List<String> integrations = const [],
    List<SentryPackage> packages = const [],
  }) {
    return SdkVersion(
      name: name,
      version: '1.0',
      integrations: integrations,
      packages: packages,
    );
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
    Contexts? contexts,
    List<String> integrations = const ['EventIntegration'],
    List<SentryPackage> packages = const [],
  }) {
    if (packages.isEmpty) {
      packages = [SentryPackage('event-package', '2.0')];
    }
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
      contexts: contexts,
    );
  }

  group(LoadContextsIntegration, () {
    late IntegrationTestFixture<LoadContextsIntegration> fixture;

    setUp(() {
      fixture = IntegrationTestFixture(LoadContextsIntegration.new);
      // Default stub - tests can override this
      when(fixture.binding.loadContexts()).thenAnswer((_) async => null);
    });

    void mockLoadContexts([Map<String, dynamic>? contexts]) {
      when(fixture.binding.loadContexts())
          .thenAnswer((_) async => contexts ?? defaultContexts);
    }

    test('adds integration to sdk.integrations', () async {
      await fixture.registerIntegration();

      expect(
        fixture.options.sdk.integrations.contains('loadContextsIntegration'),
        true,
      );
    });

    test('applies loadContextsIntegration eventProcessor', () async {
      mockLoadContexts();
      await fixture.registerIntegration();

      expect(fixture.options.eventProcessors.length, 1);

      final e = SentryEvent();
      e.contexts.operatingSystem = SentryOperatingSystem(theme: 'theme1');
      e.contexts.app = SentryApp(inForeground: true);

      final event =
          await fixture.options.eventProcessors.first.apply(e, Hint());

      verify(fixture.binding.loadContexts()).called(1);
      expect(event?.contexts.device?.name, 'Device1');
      expect(event?.contexts.app?.name, 'test-app');
      expect(event?.contexts.app?.inForeground, true);
      expect(event?.contexts.operatingSystem?.name, 'fixture-os-name');
      expect(event?.contexts.operatingSystem?.theme, 'theme1');
      expect(event?.contexts.gpu?.name, 'gpu1');
      expect(event?.contexts.browser?.name, 'browser1');
      expect(event?.contexts.runtimes.any((element) => element.name == 'RT1'),
          true);
      expect(event?.contexts['theme'], 'material');
      expect(
        event?.sdk?.packages.any((element) => element.name == 'native-package'),
        true,
      );
      expect(event?.sdk?.integrations.contains('NativeIntegration'), true);
      expect(event?.user?.id, '196E065A-AAF7-409A-9A6C-A81F40274CB9');
    });

    test('does not override event contexts with loadContextsIntegration infos',
        () async {
      mockLoadContexts();
      await fixture.registerIntegration();

      final eventContexts = Contexts(
        device: SentryDevice(name: 'eDevice'),
        app: SentryApp(name: 'eApp', inForeground: true),
        operatingSystem: SentryOperatingSystem(name: 'eOS'),
        gpu: SentryGpu(name: 'eGpu'),
        browser: SentryBrowser(name: 'eBrowser'),
        runtimes: [SentryRuntime(name: 'eRT')],
      )..['theme'] = 'cuppertino';

      final e = getEvent(
        contexts: eventContexts,
        user: SentryUser(id: 'myId'),
      );

      final event =
          await fixture.options.eventProcessors.first.apply(e, Hint());

      verify(fixture.binding.loadContexts()).called(1);
      expect(event?.contexts.device?.name, 'eDevice');
      expect(event?.contexts.app?.name, 'eApp');
      expect(event?.contexts.app?.inForeground, true);
      expect(event?.contexts.operatingSystem?.name, 'eOS');
      expect(event?.contexts.gpu?.name, 'eGpu');
      expect(event?.contexts.browser?.name, 'eBrowser');
      expect(event?.contexts.runtimes.any((element) => element.name == 'RT1'),
          true);
      expect(event?.contexts.runtimes.any((element) => element.name == 'eRT'),
          true);
      expect(event?.contexts['theme'], 'cuppertino');
      expect(event?.user?.id, 'myId');
    });

    test(
        'merges event and loadContextsIntegration sdk packages and integration',
        () async {
      mockLoadContexts();
      await fixture.registerIntegration();

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
    });

    test('does not duplicate integration if already there', () async {
      mockLoadContexts({
        'integrations': ['EventIntegration']
      });
      await fixture.registerIntegration();

      final e = getEvent();
      final event =
          await fixture.options.eventProcessors.first.apply(e, Hint());

      expect(
        event?.sdk?.integrations
            .where((element) => element == 'EventIntegration')
            .length,
        1,
      );
    });

    test('does not duplicate package if already there', () async {
      mockLoadContexts({
        'package': {'sdk_name': 'event-package', 'version': '2.0'}
      });
      await fixture.registerIntegration();

      final e = getEvent();
      final event =
          await fixture.options.eventProcessors.first.apply(e, Hint());

      expect(
        event?.sdk?.packages
            .where((element) =>
                element.name == 'event-package' && element.version == '2.0')
            .length,
        1,
      );
    });

    test('adds package if different version', () async {
      mockLoadContexts({
        'package': {'sdk_name': 'event-package', 'version': '3.0'}
      });
      await fixture.registerIntegration();

      final e = getEvent();
      final event =
          await fixture.options.eventProcessors.first.apply(e, Hint());

      expect(
        event?.sdk?.packages
            .where((element) =>
                element.name == 'event-package' && element.version == '2.0')
            .length,
        1,
      );
      expect(
        event?.sdk?.packages
            .where((element) =>
                element.name == 'event-package' && element.version == '3.0')
            .length,
        1,
      );
    });

    group('breadcrumbs', () {
      test('takes breadcrumbs from native if scope sync is enabled', () async {
        await fixture.registerIntegration();
        fixture.options.enableScopeSync = true;

        final eventBreadcrumb = Breadcrumb(message: 'event');
        var event = SentryEvent(breadcrumbs: [eventBreadcrumb]);

        when(fixture.binding.loadContexts()).thenAnswer((_) async => {
              'breadcrumbs': [Breadcrumb(message: 'native').toJson()]
            });

        event =
            (await fixture.options.eventProcessors.first.apply(event, Hint()))!;

        expect(event.breadcrumbs!.length, 1);
        expect(event.breadcrumbs!.first.message, 'native');
      });

      test('takes breadcrumbs from event if scope sync is disabled', () async {
        await fixture.registerIntegration();
        fixture.options.enableScopeSync = false;

        final eventBreadcrumb = Breadcrumb(message: 'event');
        var event = SentryEvent(breadcrumbs: [eventBreadcrumb]);

        when(fixture.binding.loadContexts()).thenAnswer((_) async => {
              'breadcrumbs': [Breadcrumb(message: 'native').toJson()]
            });

        event =
            (await fixture.options.eventProcessors.first.apply(event, Hint()))!;

        expect(event.breadcrumbs!.length, 1);
        expect(event.breadcrumbs!.first.message, 'event');
      });

      test('applies beforeBreadcrumb to native breadcrumbs', () async {
        await fixture.registerIntegration();
        fixture.options.enableScopeSync = true;
        fixture.options.beforeBreadcrumb = (breadcrumb, hint) {
          if (breadcrumb?.message == 'native-mutated') {
            breadcrumb?.message = 'native-mutated-applied';
            return breadcrumb;
          } else {
            return null;
          }
        };

        final eventBreadcrumb = Breadcrumb(message: 'event');
        var event = SentryEvent(breadcrumbs: [eventBreadcrumb]);

        when(fixture.binding.loadContexts()).thenAnswer((_) async => {
              'breadcrumbs': [
                Breadcrumb(message: 'native-mutated').toJson(),
                Breadcrumb(message: 'native-deleted').toJson(),
              ]
            });

        event =
            (await fixture.options.eventProcessors.first.apply(event, Hint()))!;

        expect(event.breadcrumbs!.length, 1);
        expect(event.breadcrumbs!.first.message, 'native-mutated-applied');
      });
    });

    group('tags', () {
      test('adds origin and environment tags if tags is null', () async {
        mockLoadContexts();
        await fixture.registerIntegration();

        final eventSdk = getSdkVersion(name: 'sentry.dart.flutter');
        final e = getEvent(sdk: eventSdk);
        final event =
            await fixture.options.eventProcessors.first.apply(e, Hint());

        expect(event?.tags?['event.origin'], 'flutter');
        expect(event?.tags?['event.environment'], 'dart');
      });

      test('merges origin and environment tags', () async {
        mockLoadContexts();
        await fixture.registerIntegration();

        final eventSdk = getSdkVersion(name: 'sentry.dart.flutter');
        final e = getEvent(sdk: eventSdk, tags: {'a': 'b'});
        final event =
            await fixture.options.eventProcessors.first.apply(e, Hint());

        expect(event?.tags?['event.origin'], 'flutter');
        expect(event?.tags?['event.environment'], 'dart');
        expect(event?.tags?['a'], 'b');
      });

      test('does not add origin and environment tags if not flutter sdk',
          () async {
        mockLoadContexts();
        await fixture.registerIntegration();

        final e = getEvent(tags: {});
        final event =
            await fixture.options.eventProcessors.first.apply(e, Hint());

        expect(event?.tags?.containsKey('event.origin'), false);
        expect(event?.tags?.containsKey('event.environment'), false);
      });

      test('merges tags from native without overriding flutter keys', () async {
        mockLoadContexts();
        await fixture.registerIntegration();

        final e = getEvent(tags: {'key': 'flutter', 'key-a': 'flutter'});
        final event =
            await fixture.options.eventProcessors.first.apply(e, Hint());

        expect(event?.tags?['key'], 'flutter');
        expect(event?.tags?['key-a'], 'flutter');
        expect(event?.tags?['key-b'], 'native');
      });
    });

    group('extra', () {
      test('merges extra from native without overriding flutter keys',
          () async {
        mockLoadContexts();
        await fixture.registerIntegration();

        final e = getEvent(extra: {'key': 'flutter', 'key-a': 'flutter'});
        final event =
            await fixture.options.eventProcessors.first.apply(e, Hint());

        // ignore: deprecated_member_use
        expect(event?.extra?['key'], 'flutter');
        // ignore: deprecated_member_use
        expect(event?.extra?['key-a'], 'flutter');
        // ignore: deprecated_member_use
        expect(event?.extra?['key-b'], 'native');
      });
    });

    group('user', () {
      test('sets user from native', () async {
        mockLoadContexts();
        await fixture.registerIntegration();

        final e = getEvent();
        final event =
            await fixture.options.eventProcessors.first.apply(e, Hint());

        expect(event?.user?.id, '196E065A-AAF7-409A-9A6C-A81F40274CB9');
        expect(event?.user?.username, 'fixture-username');
        expect(event?.user?.email, 'fixture-email');
        expect(event?.user?.ipAddress, 'fixture-ip_address');
        expect(event?.user?.data?['key'], 'value');
      });

      test('does not override user with native', () async {
        mockLoadContexts();
        await fixture.registerIntegration();

        final e = getEvent(user: SentryUser(id: 'abc'));
        final event =
            await fixture.options.eventProcessors.first.apply(e, Hint());

        expect(event?.user?.id, 'abc');
      });

      test(
          'applies default IP to user during captureEvent if ip is null and sendDefaultPii is true',
          () async {
        await fixture.registerIntegration();
        fixture.options.enableScopeSync = true;
        fixture.options.sendDefaultPii = true;

        const expectedIp = '{{auto}}';
        String? actualIp;
        const expectedId = '1';
        String? actualId;

        fixture.options.beforeSend = (event, hint) {
          actualIp = event.user?.ipAddress;
          actualId = event.user?.id;
          return event;
        };

        final user = SentryUser(id: expectedId);
        when(fixture.binding.loadContexts())
            .thenAnswer((_) async => {'user': user.toJson()});

        final client = SentryClient(fixture.options);
        final event = SentryEvent();

        await client.captureEvent(event);

        expect(actualIp, expectedIp);
        expect(actualId, expectedId);
      });

      test(
          'does not apply default IP to user during captureEvent if ip is null and sendDefaultPii is false',
          () async {
        await fixture.registerIntegration();
        fixture.options.enableScopeSync = true;

        String? actualIp;
        const expectedId = '1';
        String? actualId;

        fixture.options.beforeSend = (event, hint) {
          actualIp = event.user?.ipAddress;
          actualId = event.user?.id;
          return event;
        };

        final user = SentryUser(id: expectedId);
        when(fixture.binding.loadContexts())
            .thenAnswer((_) async => {'user': user.toJson()});

        final client = SentryClient(fixture.options);
        final event = SentryEvent();

        await client.captureEvent(event);

        expect(actualIp, isNull);
        expect(actualId, expectedId);
      });

      test(
          'applies default IP to user during captureTransaction if ip is null and sendDefaultPii is true',
          () async {
        await fixture.registerIntegration();
        fixture.options.enableScopeSync = true;
        fixture.options.sendDefaultPii = true;

        const expectedIp = '{{auto}}';
        String? actualIp;
        const expectedId = '1';
        String? actualId;

        fixture.options.beforeSendTransaction = (transaction, hint) {
          actualIp = transaction.user?.ipAddress;
          actualId = transaction.user?.id;
          return transaction;
        };

        final user = SentryUser(id: expectedId);
        when(fixture.binding.loadContexts())
            .thenAnswer((_) async => {'user': user.toJson()});

        final client = SentryClient(fixture.options);
        final tracer =
            SentryTracer(SentryTransactionContext('name', 'op'), fixture.hub);
        final transaction = SentryTransaction(tracer);

        await client.captureTransaction(transaction);

        expect(actualIp, expectedIp);
        expect(actualId, expectedId);
      });

      test(
          'does not apply default IP to user during captureTransaction if ip is null and sendDefaultPii is false',
          () async {
        await fixture.registerIntegration();
        fixture.options.enableScopeSync = true;

        String? actualIp;
        const expectedId = '1';
        String? actualId;

        fixture.options.beforeSendTransaction = (transaction, hint) {
          actualIp = transaction.user?.ipAddress;
          actualId = transaction.user?.id;
          return transaction;
        };

        final user = SentryUser(id: expectedId);
        when(fixture.binding.loadContexts())
            .thenAnswer((_) async => {'user': user.toJson()});

        final client = SentryClient(fixture.options);
        final tracer =
            SentryTracer(SentryTransactionContext('name', 'op'), fixture.hub);
        final transaction = SentryTransaction(tracer);

        await client.captureTransaction(transaction);

        expect(actualIp, isNull);
        expect(actualId, expectedId);
      });
    });

    group('dist', () {
      test('sets dist from native', () async {
        mockLoadContexts();
        await fixture.registerIntegration();

        final e = getEvent();
        final event =
            await fixture.options.eventProcessors.first.apply(e, Hint());

        expect(event?.dist, 'fixture-dist');
      });

      test('does not override dist with native', () async {
        mockLoadContexts();
        await fixture.registerIntegration();

        final e = getEvent(dist: 'abc');
        final event =
            await fixture.options.eventProcessors.first.apply(e, Hint());

        expect(event?.dist, 'abc');
      });
    });

    group('environment', () {
      test('sets environment from native', () async {
        mockLoadContexts();
        await fixture.registerIntegration();

        final e = getEvent();
        final event =
            await fixture.options.eventProcessors.first.apply(e, Hint());

        expect(event?.environment, 'fixture-environment');
      });

      test('does not override environment with native', () async {
        mockLoadContexts();
        await fixture.registerIntegration();

        final e = getEvent(environment: 'abc');
        final event =
            await fixture.options.eventProcessors.first.apply(e, Hint());

        expect(event?.environment, 'abc');
      });
    });

    group('fingerprint', () {
      test('merges fingerprint from native without duplicating entries',
          () async {
        mockLoadContexts();
        await fixture.registerIntegration();

        final e = getEvent(fingerprint: ['fingerprint-a', 'fingerprint-b']);
        final event =
            await fixture.options.eventProcessors.first.apply(e, Hint());

        expect(event?.fingerprint, ['fingerprint-a', 'fingerprint-b']);
      });
    });

    group('level', () {
      test('sets level from native', () async {
        mockLoadContexts();
        await fixture.registerIntegration();

        final e = getEvent();
        final event =
            await fixture.options.eventProcessors.first.apply(e, Hint());

        expect(event?.level, SentryLevel.error);
      });

      test('does not override level with native', () async {
        mockLoadContexts();
        await fixture.registerIntegration();

        final e = getEvent(level: SentryLevel.fatal);
        final event =
            await fixture.options.eventProcessors.first.apply(e, Hint());

        expect(event?.level, SentryLevel.fatal);
      });
    });

    group('logs', () {
      test('adds os and device attributes to log', () async {
        fixture.options.enableLogs = true;
        await fixture.registerIntegration();

        when(fixture.binding.loadContexts())
            .thenAnswer((_) async => defaultContexts);

        final log = givenLog();
        await fixture.hub.captureLog(log);

        expect(log.attributes['os.name']?.value, 'fixture-os-name');
        expect(log.attributes['os.version']?.value, 'fixture-os-version');
        expect(log.attributes['device.brand']?.value, 'fixture-device-brand');
        expect(log.attributes['device.model']?.value, 'fixture-device-model');
        expect(log.attributes['device.family']?.value, 'fixture-device-family');
      });

      test(
          'does not add os and device attributes to log if enableLogs is false',
          () async {
        fixture.options.enableLogs = false;
        await fixture.registerIntegration();

        when(fixture.binding.loadContexts())
            .thenAnswer((_) async => defaultContexts);

        final log = givenLog();
        await fixture.hub.captureLog(log);

        expect(log.attributes['os.name'], isNull);
        expect(log.attributes['os.version'], isNull);
        expect(log.attributes['device.brand'], isNull);
        expect(log.attributes['device.model'], isNull);
        expect(log.attributes['device.family'], isNull);
      });

      test('handles throw during loadContexts', () async {
        fixture.options.enableLogs = true;
        await fixture.registerIntegration();

        when(fixture.binding.loadContexts()).thenThrow(Exception('test'));

        final log = givenLog();
        await fixture.hub.captureLog(log);

        // os.name and os.version are set by defaultAttributes() from Dart-level
        // OS detection, not from native loadContexts(), so we only check device.*
        expect(log.attributes['device.brand'], isNull);
        expect(log.attributes['device.model'], isNull);
        expect(log.attributes['device.family'], isNull);
      });

      test('handles throw during loadContexts', () async {
        fixture.options.enableLogs = true;
        await fixture.registerIntegration();

        when(fixture.binding.loadContexts()).thenThrow(Exception('test'));

        final log = givenLog();
        await fixture.hub.captureLog(log);

        // os.name and os.version are set by defaultAttributes() from Dart-level
        // OS detection, not from native loadContexts(), so we only check device.*
        expect(log.attributes['device.brand'], isNull);
        expect(log.attributes['device.model'], isNull);
        expect(log.attributes['device.family'], isNull);
      });
    });

    group('metrics', () {
      test('adds native attributes to metric when metrics enabled', () async {
        fixture.options.enableMetrics = true;
        mockLoadContexts();
        await fixture.registerIntegration();

        expect(fixture.options.lifecycleRegistry.lifecycleCallbacks.length, 1);

        final metric = SentryCounterMetric(
          timestamp: DateTime.now(),
          name: 'random',
          value: 1,
          traceId: SentryId.newId(),
        );

        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessMetric(metric));

        verify(fixture.binding.loadContexts()).called(1);
        final attributes = metric.attributes;
        expect(attributes[SemanticAttributesConstants.osName]?.value,
            'fixture-os-name');
        expect(attributes[SemanticAttributesConstants.osVersion]?.value,
            'fixture-os-version');
        expect(attributes[SemanticAttributesConstants.deviceBrand]?.value,
            'fixture-device-brand');
        expect(attributes[SemanticAttributesConstants.deviceModel]?.value,
            'fixture-device-model');
        expect(attributes[SemanticAttributesConstants.deviceFamily]?.value,
            'fixture-device-family');
      });

      test('does not register callback when metrics disabled', () async {
        fixture.options.enableMetrics = false;
        await fixture.registerIntegration();

        expect(fixture.options.lifecycleRegistry.lifecycleCallbacks.length, 0);
      });
    });

    group('spans', () {
      RecordingSentrySpanV2 givenSpan() {
        return RecordingSentrySpanV2.root(
          name: 'test-span',
          traceId: SentryId.newId(),
          onSpanEnd: (_) async {},
          clock: fixture.options.clock,
          dscCreator: (s) => SentryTraceContextHeader(SentryId.newId(), 'key'),
          samplingDecision: SentryTracesSamplingDecision(true),
        );
      }

      test('adds native attributes to span when traceLifecycle is streaming',
          () async {
        fixture.options.traceLifecycle = SentryTraceLifecycle.streaming;
        mockLoadContexts();
        await fixture.registerIntegration();

        expect(
          fixture.options.lifecycleRegistry.lifecycleCallbacks[OnProcessSpan],
          isNotEmpty,
        );

        final span = givenSpan();
        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessSpan(span));

        verify(fixture.binding.loadContexts()).called(1);
        final attributes = span.attributes;
        expect(attributes[SemanticAttributesConstants.osName]?.value,
            'fixture-os-name');
        expect(attributes[SemanticAttributesConstants.osVersion]?.value,
            'fixture-os-version');
        expect(attributes[SemanticAttributesConstants.deviceBrand]?.value,
            'fixture-device-brand');
        expect(attributes[SemanticAttributesConstants.deviceModel]?.value,
            'fixture-device-model');
        expect(attributes[SemanticAttributesConstants.deviceFamily]?.value,
            'fixture-device-family');
      });

      test('does not override existing span attributes', () async {
        fixture.options.traceLifecycle = SentryTraceLifecycle.streaming;
        mockLoadContexts();
        await fixture.registerIntegration();

        final span = givenSpan();
        span.setAttribute(SemanticAttributesConstants.osName,
            SentryAttribute.string('existing-os-name'));

        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessSpan(span));

        final attributes = span.attributes;
        expect(attributes[SemanticAttributesConstants.osName]?.value,
            'existing-os-name');
        // Other attributes should still be added
        expect(attributes[SemanticAttributesConstants.osVersion]?.value,
            'fixture-os-version');
      });

      test(
          'does not register callback when traceLifecycle is not streaming',
          () async {
        fixture.options.traceLifecycle = SentryTraceLifecycle.static;
        await fixture.registerIntegration();

        expect(
          fixture.options.lifecycleRegistry.lifecycleCallbacks[OnProcessSpan],
          isNull,
        );
      });

      test('handles throw during loadContexts', () async {
        fixture.options.traceLifecycle = SentryTraceLifecycle.streaming;
        await fixture.registerIntegration();

        when(fixture.binding.loadContexts()).thenThrow(Exception('test'));

        final span = givenSpan();
        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessSpan(span));

        // Attributes should remain unchanged (empty or just what was set before)
        expect(span.attributes[SemanticAttributesConstants.deviceBrand], isNull);
        expect(span.attributes[SemanticAttributesConstants.deviceModel], isNull);
        expect(span.attributes[SemanticAttributesConstants.deviceFamily], isNull);
      });
    });

    group('close', () {
      test('removes metric callback from lifecycle registry', () async {
        fixture.options.enableMetrics = true;
        mockLoadContexts();
        await fixture.registerIntegration();

        expect(fixture.options.lifecycleRegistry.lifecycleCallbacks.length, 1);

        fixture.sut.close();

        expect(
          fixture.options.lifecycleRegistry.lifecycleCallbacks[OnProcessMetric],
          isEmpty,
        );
      });

      test('removes log callback from lifecycle registry', () async {
        fixture.options.enableLogs = true;
        await fixture.registerIntegration();

        expect(
          fixture.options.lifecycleRegistry.lifecycleCallbacks[OnProcessLog],
          isNotEmpty,
        );

        fixture.sut.close();

        expect(
          fixture.options.lifecycleRegistry.lifecycleCallbacks[OnProcessLog],
          isEmpty,
        );
      });

      test('removes span callback from lifecycle registry', () async {
        fixture.options.traceLifecycle = SentryTraceLifecycle.streaming;
        mockLoadContexts();
        await fixture.registerIntegration();

        expect(
          fixture.options.lifecycleRegistry.lifecycleCallbacks[OnProcessSpan],
          isNotEmpty,
        );

        fixture.sut.close();

        expect(
          fixture.options.lifecycleRegistry.lifecycleCallbacks[OnProcessSpan],
          isEmpty,
        );
      });

      test('removes all callbacks when all features enabled', () async {
        fixture.options.enableMetrics = true;
        fixture.options.enableLogs = true;
        fixture.options.traceLifecycle = SentryTraceLifecycle.streaming;
        mockLoadContexts();
        await fixture.registerIntegration();

        expect(fixture.options.lifecycleRegistry.lifecycleCallbacks.length, 3);

        fixture.sut.close();

        expect(
          fixture.options.lifecycleRegistry.lifecycleCallbacks[OnProcessMetric],
          isEmpty,
        );
        expect(
          fixture.options.lifecycleRegistry.lifecycleCallbacks[OnProcessLog],
          isEmpty,
        );
        expect(
          fixture.options.lifecycleRegistry.lifecycleCallbacks[OnProcessSpan],
          isEmpty,
        );
      });

      test('metric callback is not invoked after close', () async {
        fixture.options.enableMetrics = true;
        mockLoadContexts();
        await fixture.registerIntegration();

        fixture.sut.close();

        final metric = SentryCounterMetric(
          timestamp: DateTime.now(),
          name: 'random',
          value: 1,
          traceId: SentryId.newId(),
        );

        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessMetric(metric));

        verifyNever(fixture.binding.loadContexts());
        expect(metric.attributes, isEmpty);
      });

      test('span callback is not invoked after close', () async {
        fixture.options.traceLifecycle = SentryTraceLifecycle.streaming;
        mockLoadContexts();
        await fixture.registerIntegration();

        fixture.sut.close();

        final span = RecordingSentrySpanV2.root(
          name: 'test-span',
          traceId: SentryId.newId(),
          onSpanEnd: (_) async {},
          clock: fixture.options.clock,
          dscCreator: (s) => SentryTraceContextHeader(SentryId.newId(), 'key'),
          samplingDecision: SentryTracesSamplingDecision(true),
        );

        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessSpan(span));

        verifyNever(fixture.binding.loadContexts());
        expect(span.attributes, isEmpty);
      });
    });
  });
}
