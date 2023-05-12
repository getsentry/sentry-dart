@TestOn('vm')

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
      event = (await fixture.options.eventProcessors.first.apply(event))!;

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
      event = (await fixture.options.eventProcessors.first.apply(event))!;

      expect(event.breadcrumbs!.length, 1);
      expect(event.breadcrumbs!.first.message, 'event');
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryFlutterOptions(dsn: fakeDsn);

  final methodChannel = MockMethodChannel();
}
