@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/load_contexts_integration.dart';
import 'fixture.dart';

void main() {
  final infosJson = {
    'contexts': {
      'device': {
        'family': 'fixture-device-family',
        'model': 'fixture-device-model',
        'brand': 'fixture-device-brand',
      },
      'os': {
        'name': 'fixture-os-name',
        'version': 'fixture-os-version',
      },
    }
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

  group(LoadContextsIntegration, () {
    late IntegrationTestFixture fixture;

    setUp(() {
      fixture = IntegrationTestFixture(LoadContextsIntegration.new);
    });

    test('loadContextsIntegration adds integration', () async {
      await fixture.registerIntegration();

      expect(
          fixture.options.sdk.integrations.contains('loadContextsIntegration'),
          true);
    });

    test('take breadcrumbs from native if scope sync is enabled', () async {
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

    test('take breadcrumbs from event if scope sync is disabled', () async {
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

    test('apply beforeBreadcrumb to native breadcrumbs', () async {
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

    test(
        'apply default IP to user during captureEvent after loading context if ip is null and sendDefaultPii is true',
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

      final options = fixture.options;

      final user = SentryUser(id: expectedId);
      when(fixture.binding.loadContexts())
          .thenAnswer((_) async => {'user': user.toJson()});

      final client = SentryClient(options);
      final event = SentryEvent();

      await client.captureEvent(event);

      expect(actualIp, expectedIp);
      expect(actualId, expectedId);
    });

    test(
        'does not apply default IP to user during captureEvent after loading context if ip is null and sendDefaultPii is false',
        () async {
      await fixture.registerIntegration();
      fixture.options.enableScopeSync = true;
      // sendDefaultPii false is by default

      String? actualIp;

      const expectedId = '1';
      String? actualId;

      fixture.options.beforeSend = (event, hint) {
        actualIp = event.user?.ipAddress;
        actualId = event.user?.id;
        return event;
      };

      final options = fixture.options;

      final user = SentryUser(id: expectedId);
      when(fixture.binding.loadContexts())
          .thenAnswer((_) async => {'user': user.toJson()});

      final client = SentryClient(options);
      final event = SentryEvent();

      await client.captureEvent(event);

      expect(actualIp, isNull);
      expect(actualId, expectedId);
    });

    test(
        'apply default IP to user during captureTransaction after loading context if ip is null and sendDefaultPii is true',
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

      final options = fixture.options;

      final user = SentryUser(id: expectedId);
      when(fixture.binding.loadContexts())
          .thenAnswer((_) async => {'user': user.toJson()});

      final client = SentryClient(options);
      final tracer =
          SentryTracer(SentryTransactionContext('name', 'op'), fixture.hub);
      final transaction = SentryTransaction(tracer);

      // ignore: invalid_use_of_internal_member
      await client.captureTransaction(transaction);

      expect(actualIp, expectedIp);
      expect(actualId, expectedId);
    });

    test(
        'does not apply default IP to user during captureTransaction after loading context if ip is null and sendDefaultPii is false',
        () async {
      await fixture.registerIntegration();
      fixture.options.enableScopeSync = true;
      // sendDefaultPii false is by default

      String? actualIp;

      const expectedId = '1';
      String? actualId;

      fixture.options.beforeSendTransaction = (transaction, hint) {
        actualIp = transaction.user?.ipAddress;
        actualId = transaction.user?.id;
        return transaction;
      };

      final options = fixture.options;

      final user = SentryUser(id: expectedId);
      when(fixture.binding.loadContexts())
          .thenAnswer((_) async => {'user': user.toJson()});

      final client = SentryClient(options);
      final tracer =
          SentryTracer(SentryTransactionContext('name', 'op'), fixture.hub);
      final transaction = SentryTransaction(tracer);

      // ignore: invalid_use_of_internal_member
      await client.captureTransaction(transaction);

      expect(actualIp, isNull);
      expect(actualId, expectedId);
    });

    test('add os and device attributes to log', () async {
      fixture.options.enableLogs = true;

      await fixture.registerIntegration();

      when(fixture.binding.loadContexts()).thenAnswer((_) async => infosJson);

      final log = givenLog();
      await fixture.hub.captureLog(log);

      expect(log.attributes['os.name']?.value, 'fixture-os-name');
      expect(log.attributes['os.version']?.value, 'fixture-os-version');
      expect(log.attributes['device.brand']?.value, 'fixture-device-brand');
      expect(log.attributes['device.model']?.value, 'fixture-device-model');
      expect(log.attributes['device.family']?.value, 'fixture-device-family');
    });

    test('does not add os and device attributes to log if enableLogs is false',
        () async {
      fixture.options.enableLogs = false;
      await fixture.registerIntegration();

      when(fixture.binding.loadContexts()).thenAnswer((_) async => infosJson);

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

      expect(log.attributes['os.name'], isNull);
      expect(log.attributes['os.version'], isNull);
      expect(log.attributes['device.brand'], isNull);
      expect(log.attributes['device.model'], isNull);
      expect(log.attributes['device.family'], isNull);
    });
  });
}
