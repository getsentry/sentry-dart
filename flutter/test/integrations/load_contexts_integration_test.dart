@TestOn('vm')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/load_contexts_integration.dart';

import 'fixture.dart';

void main() {
  group(LoadContextsIntegration, () {
    late IntegrationTestFixture<LoadContextsIntegration> fixture;

    setUp(() async {
      fixture = IntegrationTestFixture(LoadContextsIntegration.new);
      await fixture.registerIntegration();
    });

    test('loadContextsIntegration adds integration', () {
      expect(
          fixture.options.sdk.integrations.contains('loadContextsIntegration'),
          true);
    });

    test('take breadcrumbs from native if scope sync is enabled', () async {
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
      fixture.options.enableScopeSync = true;
      fixture.options.beforeBreadcrumb = (breadcrumb, hint) {
        if (breadcrumb?.message == 'native-mutated') {
          return breadcrumb?.copyWith(message: 'native-mutated-applied');
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
}
