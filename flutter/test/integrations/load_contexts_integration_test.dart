@TestOn('vm')
library flutter_test;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/load_contexts_integration.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  group(LoadContextsIntegration, () {
    const _channel = MethodChannel('sentry_flutter');

    TestWidgetsFlutterBinding.ensureInitialized();

    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    tearDown(() {
      // ignore: deprecated_member_use
      _channel.setMockMethodCallHandler(null);
    });

    test('loadContextsIntegration adds integration', () {
      // ignore: deprecated_member_use
      _channel.setMockMethodCallHandler((MethodCall methodCall) async {});

      final integration = LoadContextsIntegration(_channel);

      integration(fixture.hub, fixture.options);

      expect(
          fixture.options.sdk.integrations.contains('loadContextsIntegration'),
          true);
    });

    test('take breadcrumbs from native if scope sync is enabled', () async {
      fixture.options.enableScopeSync = true;

      final eventBreadcrumb = Breadcrumb(message: 'event');
      var event = SentryEvent(breadcrumbs: [eventBreadcrumb]);

      final nativeBreadcrumb = Breadcrumb(message: 'native');
      Map<String, dynamic> loadContexts = {
        'breadcrumbs': [nativeBreadcrumb.toJson()]
      };

      final future = Future.value(loadContexts);
      when(fixture.methodChannel.invokeMethod<dynamic>('loadContexts'))
          .thenAnswer((_) => future);
      // ignore: deprecated_member_use
      _channel.setMockMethodCallHandler((MethodCall methodCall) async {});

      final integration = LoadContextsIntegration(fixture.methodChannel);
      integration.call(fixture.hub, fixture.options);
      event =
          (await fixture.options.eventProcessors.first.apply(event, Hint()))!;

      expect(event.breadcrumbs!.length, 1);
      expect(event.breadcrumbs!.first.message, 'native');
    });

    test('take breadcrumbs from event if scope sync is disabled', () async {
      fixture.options.enableScopeSync = false;

      final eventBreadcrumb = Breadcrumb(message: 'event');
      var event = SentryEvent(breadcrumbs: [eventBreadcrumb]);

      final nativeBreadcrumb = Breadcrumb(message: 'native');
      Map<String, dynamic> loadContexts = {
        'breadcrumbs': [nativeBreadcrumb.toJson()]
      };

      final future = Future.value(loadContexts);
      when(fixture.methodChannel.invokeMethod<dynamic>('loadContexts'))
          .thenAnswer((_) => future);
      // ignore: deprecated_member_use
      _channel.setMockMethodCallHandler((MethodCall methodCall) async {});

      final integration = LoadContextsIntegration(fixture.methodChannel);
      integration.call(fixture.hub, fixture.options);
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

      final nativeMutatedBreadcrumb = Breadcrumb(message: 'native-mutated');
      final nativeDeletedBreadcrumb = Breadcrumb(message: 'native-deleted');
      Map<String, dynamic> loadContexts = {
        'breadcrumbs': [
          nativeMutatedBreadcrumb.toJson(),
          nativeDeletedBreadcrumb.toJson(),
        ]
      };

      final future = Future.value(loadContexts);
      when(fixture.methodChannel.invokeMethod<dynamic>('loadContexts'))
          .thenAnswer((_) => future);
      // ignore: deprecated_member_use
      _channel.setMockMethodCallHandler((MethodCall methodCall) async {});

      final integration = LoadContextsIntegration(fixture.methodChannel);
      integration.call(fixture.hub, fixture.options);
      event =
          (await fixture.options.eventProcessors.first.apply(event, Hint()))!;

      expect(event.breadcrumbs!.length, 1);
      expect(event.breadcrumbs!.first.message, 'native-mutated-applied');
    });

    test('apply default IP to user during captureEvent after loading context',
        () async {
      fixture.options.enableScopeSync = true;

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
      Map<String, dynamic> loadContexts = {'user': user.toJson()};
      final future = Future.value(loadContexts);
      when(fixture.methodChannel.invokeMethod<dynamic>('loadContexts'))
          .thenAnswer((_) => future);
      // ignore: deprecated_member_use
      _channel.setMockMethodCallHandler((MethodCall methodCall) async {});

      final integration = LoadContextsIntegration(fixture.methodChannel);
      options.addIntegration(integration);
      options.integrations.first.call(fixture.hub, options);

      final client = SentryClient(options);
      final event = SentryEvent();

      await client.captureEvent(event);

      expect(expectedIp, actualIp);
      expect(expectedId, actualId);
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryFlutterOptions(dsn: fakeDsn);

  final methodChannel = MockMethodChannel();
}
