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

    test('merging breadcrumbs removes duplicates', () async {
      final breadcrumb = Breadcrumb(
        message: "fixture-message",
        data: {'LogRecord.sequenceNumber': 0},
      );
      final otherBreadcrumb = Breadcrumb(
        message: "other",
        data: {'LogRecord.sequenceNumber': 1},
      );
      var event = SentryEvent(breadcrumbs: [breadcrumb]);

      Map<String, dynamic> loadContexts = {
        'breadcrumbs': [breadcrumb.toJson(), otherBreadcrumb.toJson()]
      };
      final future = Future.value(loadContexts);
      when(fixture.methodChannel.invokeMethod<dynamic>('loadContexts'))
          .thenAnswer((_) => future);

      _channel.setMockMethodCallHandler((MethodCall methodCall) async {});

      final integration = LoadContextsIntegration(fixture.methodChannel);
      integration.call(fixture.hub, fixture.options);
      event = (await fixture.options.eventProcessors.first.apply(event))!;

      expect(event.breadcrumbs!.length, 2);
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
