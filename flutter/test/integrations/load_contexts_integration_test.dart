@TestOn('vm')

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
      _channel.setMockMethodCallHandler(null);
    });

    test('loadContextsIntegration adds integration', () async {
      _channel.setMockMethodCallHandler((MethodCall methodCall) async {});

      final integration = LoadContextsIntegration(_channel);

      await integration(fixture.hub, fixture.options);

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
      _channel.setMockMethodCallHandler((MethodCall methodCall) async {});

      final integration = LoadContextsIntegration(fixture.methodChannel);
      integration.call(fixture.hub, fixture.options);
      event = (await fixture.options.eventProcessors.first.apply(event))!;

      expect(event.breadcrumbs!.length, 1);
      expect(event.breadcrumbs!.first.message, 'event');
    });

    test('should sort native breadcrumbs by timestamp', () async {
      fixture.options.enableScopeSync = true;

      final beforeCrumb = Breadcrumb(
          message: 'before', timestamp: DateTime.fromMicrosecondsSinceEpoch(0));
      final afterCrumb = Breadcrumb(
          message: 'after',
          timestamp: DateTime.fromMicrosecondsSinceEpoch(1000));
      Map<String, dynamic> loadContexts = {
        'breadcrumbs': [afterCrumb.toJson(), beforeCrumb.toJson()]
      };

      var event = SentryEvent(breadcrumbs: []);

      final future = Future.value(loadContexts);
      when(fixture.methodChannel.invokeMethod<dynamic>('loadContexts'))
          .thenAnswer((_) => future);
      _channel.setMockMethodCallHandler((MethodCall methodCall) async {});

      final integration = LoadContextsIntegration(fixture.methodChannel);
      integration.call(fixture.hub, fixture.options);
      event = (await fixture.options.eventProcessors.first.apply(event))!;

      expect(event.breadcrumbs!.length, 2);
      expect(event.breadcrumbs![0].message, 'before');
      expect(event.breadcrumbs![1].message, 'after');
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryFlutterOptions(dsn: fakeDsn);
  final methodChannel = MockMethodChannel();

  LoadReleaseIntegration getIntegration({PackageLoader? loader}) {
    return LoadReleaseIntegration(loader ?? loadRelease);
  }

  Future<PackageInfo> loadRelease() {
    return Future.value(PackageInfo(
      appName: 'sentry_flutter',
      packageName: 'foo.bar',
      version: '1.2.3',
      buildNumber: '789',
      buildSignature: '',
    ));
  }
}
