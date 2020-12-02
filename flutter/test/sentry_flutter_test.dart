import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:package_info/package_info.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'mocks.dart';
import 'sentry_flutter_util.dart';

void main() {
  const _channel = MethodChannel('sentry_flutter');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {});
  });

  tearDown(() {
    _channel.setMockMethodCallHandler(null);
    Sentry.close();
  });

  test('Flutter init for mobile will run default configurations', () async {
    await SentryFlutter.init(
      getConfigurationTester(isIOS: true, isAndroid: true),
      appRunner: appRunner,
      packageLoader: loadTestPackage,
      isIOSChecker: () => true,
      isAndroidChecker: () => true,
    );
  });

  test('Flutter init for mobile will run default configurations on ios',
      () async {
    await SentryFlutter.init(
      getConfigurationTester(isIOS: true),
      isIOSChecker: () => true,
    );
  });

  group('platform based loadContextsIntegration', () {
    final transport = MockTransport();

    setUp(() {
      _channel.setMockMethodCallHandler(
        (MethodCall methodCall) async => <String, dynamic>{},
      );
      when(transport.send(any))
          .thenAnswer((realInvocation) => Future.value(SentryId.newId()));
    });

    tearDown(() {
      _channel.setMockMethodCallHandler(null);
      Sentry.close();
    });

    test('should add loadContextsIntegration on ios', () async {
      await SentryFlutter.init(
        (options) => options
          ..dsn = fakeDsn
          ..transport = transport,
        isIOSChecker: () => true,
      );

      await Sentry.captureMessage('a message');

      final event =
          verify(transport.send(captureAny)).captured.first as SentryEvent;

      expect(event.sdk.integrations.length, 5);
      expect(event.sdk.integrations.contains('loadContextsIntegration'), true);
    });

    test('should not add loadContextsIntegration if not ios', () async {
      await SentryFlutter.init(
        (options) => options
          ..dsn = fakeDsn
          ..transport = transport,
        isIOSChecker: () => false,
        // packageLoader: loadTestPackage,
      );

      await Sentry.captureMessage('a message');

      final event =
          verify(transport.send(captureAny)).captured.first as SentryEvent;

      expect(event.sdk.integrations.length, 4);
      expect(event.sdk.integrations.contains('loadContextsIntegration'), false);
    });

    test('should not add loadAndroidImageListIntegration if not Android',
        () async {
      await SentryFlutter.init(
        (options) => options
          ..dsn = fakeDsn
          ..transport = transport,
        isAndroidChecker: () => false,
        // packageLoader: loadTestPackage,
      );

      await Sentry.captureMessage('a message');

      final event =
          verify(transport.send(captureAny)).captured.first as SentryEvent;

      expect(event.sdk.integrations.length, 4);
      expect(event.sdk.integrations.contains('loadAndroidImageListIntegration'),
          false);
    });
  });
}

void appRunner() {}

Future<PackageInfo> loadTestPackage() async {
  return PackageInfo(
    appName: 'appName',
    packageName: 'packageName',
    version: 'version',
    buildNumber: 'buildNumber',
  );
}
