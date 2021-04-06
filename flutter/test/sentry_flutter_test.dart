import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'mocks.dart';
import 'mocks.mocks.dart';
import 'sentry_flutter_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Flutter init for mobile', () {
    const _channel = MethodChannel('sentry_flutter');

    setUp(() {
      _channel.setMockMethodCallHandler((MethodCall methodCall) async {});
    });

    tearDown(() {
      Sentry.close();
    });

    test('Will run default configurations on Android', () async {
      await SentryFlutter.init(
        getConfigurationTester(isAndroid: true),
        appRunner: appRunner,
        packageLoader: loadTestPackage,
        isAndroidChecker: () => true,
        channel: _channel,
      );
    });

    test('Will run default configurations on ios', () async {
      await SentryFlutter.init(
        getConfigurationTester(isIOS: true),
        appRunner: appRunner,
        packageLoader: loadTestPackage,
        isIOSChecker: () => true,
        channel: _channel,
      );
    });
  });

  group('platform based loadContextsIntegration', () {
    const _channel = MethodChannel('sentry_flutter');
    final transport = MockTransport();

    setUp(() {
      _channel.setMockMethodCallHandler(
        (MethodCall methodCall) async => <String, dynamic>{},
      );
      when(transport.sendSentryEvent(any))
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
        packageLoader: loadTestPackage,
        isIOSChecker: () => true,
        channel: _channel,
      );

      await Sentry.captureMessage('a message');

      final event =
          verify(transport.sendSentryEvent(captureAny)).captured.first as SentryEvent;

      expect(event.sdk!.integrations.length, 7);
      expect(event.sdk!.integrations.contains('loadContextsIntegration'), true);
    });

    test('should not add loadContextsIntegration if not ios', () async {
      await SentryFlutter.init(
        (options) => options
          ..dsn = fakeDsn
          ..transport = transport,
        packageLoader: loadTestPackage,
        isIOSChecker: () => false,
        channel: _channel,
      );

      await Sentry.captureMessage('a message');

      final event =
          verify(transport.sendSentryEvent(captureAny)).captured.first as SentryEvent;

      expect(event.sdk!.integrations.length, 6);
      expect(
          event.sdk!.integrations.contains('loadContextsIntegration'), false);
    });

    test('should not add loadAndroidImageListIntegration if not Android',
        () async {
      await SentryFlutter.init(
        (options) => options
          ..dsn = fakeDsn
          ..transport = transport,
        packageLoader: loadTestPackage,
        isAndroidChecker: () => false,
        channel: _channel,
      );

      await Sentry.captureMessage('a message');

      final event =
          verify(transport.sendSentryEvent(captureAny)).captured.first as SentryEvent;

      expect(event.sdk!.integrations.length, 6);
      expect(
          event.sdk!.integrations.contains('loadAndroidImageListIntegration'),
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
