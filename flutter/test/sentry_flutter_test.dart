// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry/src/platform/platform.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/connectivity/connectivity_integration.dart';
import 'package:sentry_flutter/src/integrations/integrations.dart';
import 'package:sentry_flutter/src/integrations/screenshot_integration.dart';
import 'package:sentry_flutter/src/profiling.dart';
import 'package:sentry_flutter/src/renderer/renderer.dart';
import 'package:sentry_flutter/src/version.dart';
import 'package:sentry_flutter/src/view_hierarchy/view_hierarchy_integration.dart';
import 'mocks.dart';
import 'mocks.mocks.dart';
import 'sentry_flutter_util.dart';

/// These are the integrations which should be added on every platform.
/// They don't depend on the underlying platform.
final platformAgnosticIntegrations = [
  WidgetsFlutterBindingIntegration,
  FlutterErrorIntegration,
  LoadReleaseIntegration,
  DebugPrintIntegration,
  SentryViewHierarchyIntegration,
];

final webIntegrations = [
  ConnectivityIntegration,
];

final nonWebIntegrations = [
  OnErrorIntegration,
];

// These should be added to Android
final androidIntegrations = [
  LoadImageListIntegration,
  LoadContextsIntegration,
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
      SentryFlutter.native = null;
    });

    test('Android', () async {
      List<Integration> integrations = [];
      Transport transport = MockTransport();

      SentryFlutterOptions? sentryFlutterOptions;

      await SentryFlutter.init(
        (options) async {
          options.dsn = fakeDsn;
          options.automatedTestMode = true;
          options.profilesSampleRate = 1.0;
          integrations = options.integrations;
          transport = options.transport;
          sentryFlutterOptions = options;
        },
        appRunner: appRunner,
        platformChecker: getPlatformChecker(platform: MockPlatform.android()),
      );

      testTransport(
        transport: transport,
        hasFileSystemTransport: true,
      );

      testScopeObserver(
          options: sentryFlutterOptions!, expectedHasNativeScopeObserver: true);

      testConfiguration(
        integrations: integrations,
        shouldHaveIntegrations: [
          ...androidIntegrations,
          ...nativeIntegrations,
          ...platformAgnosticIntegrations,
          ...nonWebIntegrations,
        ],
        shouldNotHaveIntegrations: [
          ...iOsAndMacOsIntegrations,
          ...nonWebIntegrations,
        ],
      );

      integrations
          .indexWhere((element) => element is WidgetsFlutterBindingIntegration);

      testBefore(
          integrations: integrations,
          beforeIntegration: WidgetsFlutterBindingIntegration,
          afterIntegration: OnErrorIntegration);

      expect(SentryFlutter.native, isNotNull);
      expect(Sentry.currentHub.profilerFactory, isNull);

      await Sentry.close();
    }, testOn: 'vm');

    test('iOS', () async {
      List<Integration> integrations = [];
      Transport transport = MockTransport();
      SentryFlutterOptions? sentryFlutterOptions;

      await SentryFlutter.init(
        (options) async {
          options.dsn = fakeDsn;
          options.automatedTestMode = true;
          options.profilesSampleRate = 1.0;
          integrations = options.integrations;
          transport = options.transport;
          sentryFlutterOptions = options;
        },
        appRunner: appRunner,
        platformChecker: getPlatformChecker(platform: MockPlatform.iOs()),
      );

      testTransport(
        transport: transport,
        hasFileSystemTransport: true,
      );

      testScopeObserver(
          options: sentryFlutterOptions!, expectedHasNativeScopeObserver: true);

      testConfiguration(
        integrations: integrations,
        shouldHaveIntegrations: [
          ...iOsAndMacOsIntegrations,
          ...nativeIntegrations,
          ...platformAgnosticIntegrations,
          ...nonWebIntegrations,
        ],
        shouldNotHaveIntegrations: [
          ...androidIntegrations,
          ...nonWebIntegrations,
        ],
      );

      testBefore(
          integrations: integrations,
          beforeIntegration: WidgetsFlutterBindingIntegration,
          afterIntegration: OnErrorIntegration);

      expect(SentryFlutter.native, isNotNull);
      expect(Sentry.currentHub.profilerFactory,
          isInstanceOf<SentryNativeProfilerFactory>());

      await Sentry.close();
    }, testOn: 'vm');

    test('macOS', () async {
      List<Integration> integrations = [];
      Transport transport = MockTransport();
      SentryFlutterOptions? sentryFlutterOptions;

      await SentryFlutter.init(
        (options) async {
          options.dsn = fakeDsn;
          options.automatedTestMode = true;
          options.profilesSampleRate = 1.0;
          integrations = options.integrations;
          transport = options.transport;
          sentryFlutterOptions = options;
        },
        appRunner: appRunner,
        platformChecker: getPlatformChecker(platform: MockPlatform.macOs()),
      );

      testTransport(
        transport: transport,
        hasFileSystemTransport: true,
      );

      testScopeObserver(
          options: sentryFlutterOptions!, expectedHasNativeScopeObserver: true);

      testConfiguration(integrations: integrations, shouldHaveIntegrations: [
        ...iOsAndMacOsIntegrations,
        ...nativeIntegrations,
        ...platformAgnosticIntegrations,
        ...nonWebIntegrations,
      ], shouldNotHaveIntegrations: [
        ...androidIntegrations,
        ...nonWebIntegrations,
      ]);

      testBefore(
          integrations: integrations,
          beforeIntegration: WidgetsFlutterBindingIntegration,
          afterIntegration: OnErrorIntegration);

      expect(SentryFlutter.native, isNotNull);
      expect(Sentry.currentHub.profilerFactory,
          isInstanceOf<SentryNativeProfilerFactory>());

      await Sentry.close();
    }, testOn: 'vm');

    test('Windows', () async {
      List<Integration> integrations = [];
      Transport transport = MockTransport();
      SentryFlutterOptions? sentryFlutterOptions;

      await SentryFlutter.init(
        (options) async {
          options.dsn = fakeDsn;
          options.automatedTestMode = true;
          options.profilesSampleRate = 1.0;
          integrations = options.integrations;
          transport = options.transport;
          sentryFlutterOptions = options;
        },
        appRunner: appRunner,
        platformChecker: getPlatformChecker(platform: MockPlatform.windows()),
      );

      testTransport(
        transport: transport,
        hasFileSystemTransport: false,
      );

      testScopeObserver(
          options: sentryFlutterOptions!,
          expectedHasNativeScopeObserver: false);

      testConfiguration(
        integrations: integrations,
        shouldHaveIntegrations: [
          ...platformAgnosticIntegrations,
          ...nonWebIntegrations,
        ],
        shouldNotHaveIntegrations: [
          ...androidIntegrations,
          ...iOsAndMacOsIntegrations,
          ...nativeIntegrations,
          ...webIntegrations,
        ],
      );

      testBefore(
          integrations: integrations,
          beforeIntegration: WidgetsFlutterBindingIntegration,
          afterIntegration: OnErrorIntegration);

      expect(SentryFlutter.native, isNull);
      expect(Sentry.currentHub.profilerFactory, isNull);

      await Sentry.close();
    }, testOn: 'vm');

    test('Linux', () async {
      List<Integration> integrations = [];
      Transport transport = MockTransport();
      SentryFlutterOptions? sentryFlutterOptions;

      await SentryFlutter.init(
        (options) async {
          options.dsn = fakeDsn;
          options.automatedTestMode = true;
          options.profilesSampleRate = 1.0;
          integrations = options.integrations;
          transport = options.transport;
          sentryFlutterOptions = options;
        },
        appRunner: appRunner,
        platformChecker: getPlatformChecker(platform: MockPlatform.linux()),
      );

      testTransport(
        transport: transport,
        hasFileSystemTransport: false,
      );

      testScopeObserver(
          options: sentryFlutterOptions!,
          expectedHasNativeScopeObserver: false);

      testConfiguration(
        integrations: integrations,
        shouldHaveIntegrations: [
          ...platformAgnosticIntegrations,
          ...nonWebIntegrations,
        ],
        shouldNotHaveIntegrations: [
          ...androidIntegrations,
          ...iOsAndMacOsIntegrations,
          ...nativeIntegrations,
          ...webIntegrations,
        ],
      );

      testBefore(
          integrations: integrations,
          beforeIntegration: WidgetsFlutterBindingIntegration,
          afterIntegration: OnErrorIntegration);

      expect(SentryFlutter.native, isNull);
      expect(Sentry.currentHub.profilerFactory, isNull);

      await Sentry.close();
    }, testOn: 'vm');

    test('Web', () async {
      List<Integration> integrations = [];
      Transport transport = MockTransport();
      SentryFlutterOptions? sentryFlutterOptions;

      await SentryFlutter.init(
        (options) async {
          options.dsn = fakeDsn;
          options.automatedTestMode = true;
          options.profilesSampleRate = 1.0;
          integrations = options.integrations;
          transport = options.transport;
          sentryFlutterOptions = options;
        },
        appRunner: appRunner,
        platformChecker: getPlatformChecker(
          isWeb: true,
          platform: MockPlatform.linux(),
        ),
      );

      testTransport(
        transport: transport,
        hasFileSystemTransport: false,
      );

      testScopeObserver(
          options: sentryFlutterOptions!,
          expectedHasNativeScopeObserver: false);

      testConfiguration(
        integrations: integrations,
        shouldHaveIntegrations: [
          ...platformAgnosticIntegrations,
          ...webIntegrations,
        ],
        shouldNotHaveIntegrations: [
          ...androidIntegrations,
          ...iOsAndMacOsIntegrations,
          ...nativeIntegrations,
          ...nonWebIntegrations,
        ],
      );

      testBefore(
          integrations: Sentry.currentHub.options.integrations,
          beforeIntegration: RunZonedGuardedIntegration,
          afterIntegration: WidgetsFlutterBindingIntegration);

      expect(SentryFlutter.native, isNull);
      expect(Sentry.currentHub.profilerFactory, isNull);

      await Sentry.close();
    });

    test('Web && (iOS || macOS)', () async {
      List<Integration> integrations = [];
      Transport transport = MockTransport();

      // Tests that iOS || macOS integrations aren't added on a browser which
      // runs on iOS or macOS
      await SentryFlutter.init(
        (options) async {
          options.dsn = fakeDsn;
          options.automatedTestMode = true;
          integrations = options.integrations;
          transport = options.transport;
        },
        appRunner: appRunner,
        platformChecker: getPlatformChecker(
          isWeb: true,
          platform: MockPlatform.iOs(),
        ),
      );

      testTransport(
        transport: transport,
        hasFileSystemTransport: false,
      );

      testConfiguration(
        integrations: integrations,
        shouldHaveIntegrations: [
          ...platformAgnosticIntegrations,
          ...webIntegrations,
        ],
        shouldNotHaveIntegrations: [
          ...androidIntegrations,
          ...iOsAndMacOsIntegrations,
          ...nativeIntegrations,
          ...nonWebIntegrations,
        ],
      );

      testBefore(
          integrations: Sentry.currentHub.options.integrations,
          beforeIntegration: RunZonedGuardedIntegration,
          afterIntegration: WidgetsFlutterBindingIntegration);

      await Sentry.close();
    });

    test('Web && (macOS)', () async {
      List<Integration> integrations = [];
      Transport transport = MockTransport();

      // Tests that iOS || macOS integrations aren't added on a browser which
      // runs on iOS or macOS
      await SentryFlutter.init(
        (options) async {
          options.dsn = fakeDsn;
          options.automatedTestMode = true;
          integrations = options.integrations;
          transport = options.transport;
        },
        appRunner: appRunner,
        platformChecker: getPlatformChecker(
          isWeb: true,
          platform: MockPlatform.macOs(),
        ),
      );

      testTransport(
        transport: transport,
        hasFileSystemTransport: false,
      );

      testConfiguration(
        integrations: integrations,
        shouldHaveIntegrations: [
          ...platformAgnosticIntegrations,
          ...webIntegrations,
        ],
        shouldNotHaveIntegrations: [
          ...androidIntegrations,
          ...iOsAndMacOsIntegrations,
          ...nativeIntegrations,
          ...nonWebIntegrations,
        ],
      );

      testBefore(
          integrations: Sentry.currentHub.options.integrations,
          beforeIntegration: RunZonedGuardedIntegration,
          afterIntegration: WidgetsFlutterBindingIntegration);

      expect(Sentry.currentHub.profilerFactory, isNull);

      await Sentry.close();
    });

    test('Web && Android', () async {
      List<Integration> integrations = [];
      Transport transport = MockTransport();

      // Tests that Android integrations aren't added on an Android browser
      await SentryFlutter.init(
        (options) async {
          options.dsn = fakeDsn;
          options.automatedTestMode = true;
          integrations = options.integrations;
          transport = options.transport;
        },
        appRunner: appRunner,
        platformChecker: getPlatformChecker(
          isWeb: true,
          platform: MockPlatform.android(),
        ),
      );

      testTransport(
        transport: transport,
        hasFileSystemTransport: false,
      );

      testConfiguration(
        integrations: integrations,
        shouldHaveIntegrations: [
          ...platformAgnosticIntegrations,
          ...webIntegrations,
        ],
        shouldNotHaveIntegrations: [
          ...androidIntegrations,
          ...iOsAndMacOsIntegrations,
          ...nativeIntegrations,
          ...nonWebIntegrations,
        ],
      );

      testBefore(
          integrations: Sentry.currentHub.options.integrations,
          beforeIntegration: RunZonedGuardedIntegration,
          afterIntegration: WidgetsFlutterBindingIntegration);

      await Sentry.close();
    });
  });

  group('Test ScreenshotIntegration', () {
    setUp(() async {
      await Sentry.close();
    });

    test('installed on io platforms', () async {
      List<Integration> integrations = [];

      await SentryFlutter.init(
        (options) async {
          options.dsn = fakeDsn;
          options.automatedTestMode = true;
          integrations = options.integrations;
        },
        appRunner: appRunner,
        platformChecker:
            getPlatformChecker(platform: MockPlatform.iOs(), isWeb: false),
        rendererWrapper: MockRendererWrapper(FlutterRenderer.skia),
      );

      expect(
          integrations
              .map((e) => e.runtimeType)
              .contains(ScreenshotIntegration),
          true);

      await Sentry.close();
    }, testOn: 'vm');

    test('installed with canvasKit renderer', () async {
      List<Integration> integrations = [];

      await SentryFlutter.init(
        (options) async {
          options.dsn = fakeDsn;
          options.automatedTestMode = true;
          integrations = options.integrations;
        },
        appRunner: appRunner,
        platformChecker:
            getPlatformChecker(platform: MockPlatform.iOs(), isWeb: true),
        rendererWrapper: MockRendererWrapper(FlutterRenderer.canvasKit),
      );

      expect(
          integrations
              .map((e) => e.runtimeType)
              .contains(ScreenshotIntegration),
          true);

      await Sentry.close();
    }, testOn: 'vm');

    test('not installed with html renderer', () async {
      List<Integration> integrations = [];

      await SentryFlutter.init(
        (options) async {
          options.dsn = fakeDsn;
          options.automatedTestMode = true;
          integrations = options.integrations;
        },
        appRunner: appRunner,
        platformChecker:
            getPlatformChecker(platform: MockPlatform.iOs(), isWeb: true),
        rendererWrapper: MockRendererWrapper(FlutterRenderer.html),
      );

      expect(
          integrations
              .map((e) => e.runtimeType)
              .contains(ScreenshotIntegration),
          false);

      await Sentry.close();
    }, testOn: 'vm');
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
          options.automatedTestMode = true;

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

  test('resumeAppHangTracking calls native method when available', () async {
    SentryFlutter.native = MockSentryNativeBinding();
    when(SentryFlutter.native?.resumeAppHangTracking())
        .thenAnswer((_) => Future.value());

    await SentryFlutter.resumeAppHangTracking();

    verify(SentryFlutter.native?.resumeAppHangTracking()).called(1);
  });

  test('resumeAppHangTracking does nothing when native is null', () async {
    SentryFlutter.native = null;

    // This should complete without throwing an error
    await expectLater(SentryFlutter.resumeAppHangTracking(), completes);
  });

  test('pauseAppHangTracking calls native method when available', () async {
    SentryFlutter.native = MockSentryNativeBinding();
    when(SentryFlutter.native?.pauseAppHangTracking())
        .thenAnswer((_) => Future.value());

    await SentryFlutter.pauseAppHangTracking();

    verify(SentryFlutter.native?.pauseAppHangTracking()).called(1);
  });

  test('pauseAppHangTracking does nothing when native is null', () async {
    SentryFlutter.native = null;

    // This should complete without throwing an error
    await expectLater(SentryFlutter.pauseAppHangTracking(), completes);
  });
}

void appRunner() {}

void loadTestPackage() {
  PackageInfo.setMockInitialValues(
    appName: 'appName',
    packageName: 'packageName',
    version: 'version',
    buildNumber: 'buildNumber',
    buildSignature: '',
    installerStore: null,
  );
}

PlatformChecker getPlatformChecker({
  required Platform platform,
  bool isWeb = false,
}) {
  final platformChecker = PlatformChecker(
    isWeb: isWeb,
    platform: platform,
  );
  return platformChecker;
}
