import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry/src/platform_checker.dart';
import 'package:sentry_flutter/src/version.dart';
import 'mocks.dart';
import 'sentry_flutter_util.dart';

/// These are the integrations which should be added on every platform.
/// They don't depend on the underlying platform.
final platformAgnosticIntegrations = [
  FlutterErrorIntegration,
  LoadReleaseIntegration,
];

// These should only be added to Android
final androidIntegrations = [
  LoadAndroidImageListIntegration,
];

// These should be added to iOS and macOS
final iOsAndMacOsIntegrations = [
  LoadContextsIntegration,
];

// These should be added to every platform which has a native integration.
final nativeIntegrations = [
  NativeSdkIntegration,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Test platform integrations', () {
    tearDown(() async {
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
        packageLoader: loadTestPackage,
        platformChecker: getPlatformChecker(platform: MockPlatform.android()),
      );
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
        packageLoader: loadTestPackage,
        platformChecker: getPlatformChecker(platform: MockPlatform.iOs()),
      );
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
        packageLoader: loadTestPackage,
        platformChecker: getPlatformChecker(platform: MockPlatform.macOs()),
      );
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
        packageLoader: loadTestPackage,
        platformChecker: getPlatformChecker(platform: MockPlatform.windows()),
      );
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
        packageLoader: loadTestPackage,
        platformChecker: getPlatformChecker(platform: MockPlatform.linux()),
      );
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
        packageLoader: loadTestPackage,
        platformChecker: getPlatformChecker(
          isWeb: true,
          platform: MockPlatform.linux(),
        ),
      );
    });

    test('Web && (iOS || macOS) ', () async {
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
        packageLoader: loadTestPackage,
        platformChecker: getPlatformChecker(
          isWeb: true,
          platform: MockPlatform.iOs(),
        ),
      );

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
        packageLoader: loadTestPackage,
        platformChecker: getPlatformChecker(
          isWeb: true,
          platform: MockPlatform.macOs(),
        ),
      );
    });

    test('Web && Android', () async {
      // Tests that Android integrations aren't added on an Android browswer
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
        packageLoader: loadTestPackage,
        platformChecker: getPlatformChecker(
          isWeb: true,
          platform: MockPlatform.android(),
        ),
      );
    });
  });

  group('initial values', () {
    tearDown(() async {
      await Sentry.close();
    });

    test('test that initial values are set correctly', () async {
      await SentryFlutter.init(
        (options) {
          options.dsn = fakeDsn;

          expect(kDebugMode, options.debug);
          expect('debug', options.environment);
          expect(sdkName, options.sdk.name);
          expect(sdkVersion, options.sdk.version);
          expect('pub:sentry_flutter', options.sdk.packages.last.name);
          expect(sdkVersion, options.sdk.packages.last.version);
        },
        appRunner: appRunner,
        packageLoader: loadTestPackage,
        platformChecker: getPlatformChecker(
          platform: MockPlatform.android(),
          isWeb: true,
        ),
      );
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
    buildSignature: '',
  );
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
