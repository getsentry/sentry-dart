import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/debug_print_integration.dart';
import 'package:sentry_flutter/src/version.dart';
import 'mocks.dart';
import 'sentry_flutter_util.dart';

/// These are the integrations which should be added on every platform.
/// They don't depend on the underlying platform.
final platformAgnosticIntegrations = [
  FlutterErrorIntegration,
  LoadReleaseIntegration,
  DebugPrintIntegration,
];

// These should only be added to Android
final androidIntegrations = [
  LoadImageListIntegration,
];

// These should be added to iOS and macOS
final iOsAndMacOsIntegrations = [
  LoadImageListIntegration,
  LoadContextsIntegration,
];

// These should be added to every platform which has a native integration.
final nativeIntegrations = [
  NativeSdkIntegration,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Test platform integrations', () {
    setUp(() async {
      loadTestPackage();
      await Sentry.close();
    });

    test('Android', () async {
      await SentryFlutter.init(
        getConfigurationTester(
          hasFileSystemTransport: true,
          shouldHaveIntegrations: [
            ...androidIntegrations,
            ...nativeIntegrations,
            ...platformAgnosticIntegrations,
          ],
          shouldNotHaveIntegrations: iOsAndMacOsIntegrations,
        ),
        appRunner: appRunner,
        platformChecker: getPlatformChecker(platform: MockPlatform.android()),
      );

      await Sentry.close();
    }, testOn: 'vm');

    test('iOS', () async {
      await SentryFlutter.init(
        getConfigurationTester(
          hasFileSystemTransport: true,
          shouldHaveIntegrations: [
            ...iOsAndMacOsIntegrations,
            ...nativeIntegrations,
            ...platformAgnosticIntegrations,
          ],
          shouldNotHaveIntegrations: androidIntegrations,
        ),
        appRunner: appRunner,
        platformChecker: getPlatformChecker(platform: MockPlatform.iOs()),
      );

      await Sentry.close();
    }, testOn: 'vm');

    test('macOS', () async {
      await SentryFlutter.init(
        getConfigurationTester(
          hasFileSystemTransport: true,
          shouldHaveIntegrations: [
            ...iOsAndMacOsIntegrations,
            ...nativeIntegrations,
            ...platformAgnosticIntegrations,
          ],
          shouldNotHaveIntegrations: androidIntegrations,
        ),
        appRunner: appRunner,
        platformChecker: getPlatformChecker(platform: MockPlatform.macOs()),
      );

      await Sentry.close();
    }, testOn: 'vm');

    test('Windows', () async {
      await SentryFlutter.init(
        getConfigurationTester(
          hasFileSystemTransport: false,
          shouldHaveIntegrations: platformAgnosticIntegrations,
          shouldNotHaveIntegrations: [
            ...androidIntegrations,
            ...iOsAndMacOsIntegrations,
            ...nativeIntegrations,
          ],
        ),
        appRunner: appRunner,
        platformChecker: getPlatformChecker(platform: MockPlatform.windows()),
      );

      await Sentry.close();
    }, testOn: 'vm');

    test('Linux', () async {
      await SentryFlutter.init(
        getConfigurationTester(
          hasFileSystemTransport: false,
          shouldHaveIntegrations: platformAgnosticIntegrations,
          shouldNotHaveIntegrations: [
            ...androidIntegrations,
            ...iOsAndMacOsIntegrations,
            ...nativeIntegrations,
          ],
        ),
        appRunner: appRunner,
        platformChecker: getPlatformChecker(platform: MockPlatform.linux()),
      );

      await Sentry.close();
    }, testOn: 'vm');

    test('Web', () async {
      await SentryFlutter.init(
        getConfigurationTester(
          hasFileSystemTransport: false,
          shouldHaveIntegrations: platformAgnosticIntegrations,
          shouldNotHaveIntegrations: [
            ...androidIntegrations,
            ...iOsAndMacOsIntegrations,
            ...nativeIntegrations,
          ],
        ),
        appRunner: appRunner,
        platformChecker: getPlatformChecker(
          isWeb: true,
          platform: MockPlatform.linux(),
        ),
      );

      await Sentry.close();
    });

    test('Web && (iOS || macOS) ', () async {
      // Tests that iOS || macOS integrations aren't added on a browser which
      // runs on iOS or macOS
      await SentryFlutter.init(
        getConfigurationTester(
          hasFileSystemTransport: false,
          shouldHaveIntegrations: platformAgnosticIntegrations,
          shouldNotHaveIntegrations: [
            ...androidIntegrations,
            ...iOsAndMacOsIntegrations,
            ...nativeIntegrations,
          ],
        ),
        appRunner: appRunner,
        platformChecker: getPlatformChecker(
          isWeb: true,
          platform: MockPlatform.iOs(),
        ),
      );

      await Sentry.close();
    });

    test('Web && (macOS)', () async {
      // Tests that iOS || macOS integrations aren't added on a browswer which
      // runs on iOS or macOS
      await SentryFlutter.init(
        getConfigurationTester(
          hasFileSystemTransport: false,
          shouldHaveIntegrations: platformAgnosticIntegrations,
          shouldNotHaveIntegrations: [
            ...androidIntegrations,
            ...iOsAndMacOsIntegrations,
            ...nativeIntegrations,
          ],
        ),
        appRunner: appRunner,
        platformChecker: getPlatformChecker(
          isWeb: true,
          platform: MockPlatform.macOs(),
        ),
      );

      await Sentry.close();
    });

    test('Web && Android', () async {
      // Tests that Android integrations aren't added on an Android browser
      await SentryFlutter.init(
        getConfigurationTester(
          hasFileSystemTransport: false,
          shouldHaveIntegrations: platformAgnosticIntegrations,
          shouldNotHaveIntegrations: [
            ...androidIntegrations,
            ...iOsAndMacOsIntegrations,
            ...nativeIntegrations,
          ],
        ),
        appRunner: appRunner,
        platformChecker: getPlatformChecker(
          isWeb: true,
          platform: MockPlatform.android(),
        ),
      );

      await Sentry.close();
    });
  });

  group('initial values', () {
    setUp(() async {
      loadTestPackage();
      await Sentry.close();
    });

    test('test that initial values are set correctly', () async {
      await SentryFlutter.init(
        (options) {
          options.dsn = fakeDsn;

          expect(false, options.debug);
          expect('debug', options.environment);
          expect(sdkName, options.sdk.name);
          expect(sdkVersion, options.sdk.version);
          expect('pub:sentry_flutter', options.sdk.packages.last.name);
          expect(sdkVersion, options.sdk.packages.last.version);
        },
        appRunner: appRunner,
        platformChecker: getPlatformChecker(
          platform: MockPlatform.android(),
          isWeb: true,
        ),
      );

      await Sentry.close();
    });
  });
}

void appRunner() {}

void loadTestPackage() {
  PackageInfo.setMockInitialValues(
      appName: 'appName',
      packageName: 'packageName',
      version: 'version',
      buildNumber: 'buildNumber',
      buildSignature: '');
}

PlatformChecker getPlatformChecker({
  required MockPlatform platform,
  bool isWeb = false,
}) {
  final platformChecker = PlatformChecker(
    isWeb: isWeb,
    platform: platform,
  );
  return platformChecker;
}
