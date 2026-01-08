// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry/src/dart_exception_type_identifier.dart';
import 'package:sentry/src/platform/mock_platform.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/file_system_transport.dart';
import 'package:sentry_flutter/src/flutter_exception_type_identifier.dart';
import 'package:sentry_flutter/src/integrations/connectivity/connectivity_integration.dart';
import 'package:sentry_flutter/src/integrations/integrations.dart';
import 'package:sentry_flutter/src/integrations/screenshot_integration.dart';
import 'package:sentry_flutter/src/integrations/generic_app_start_integration.dart';
import 'package:sentry_flutter/src/integrations/web_session_integration.dart';
import 'package:sentry_flutter/src/profiling.dart';
import 'package:sentry_flutter/src/renderer/renderer.dart';
import 'package:sentry_flutter/src/replay/integration.dart';
import 'package:sentry_flutter/src/version.dart';
import 'package:sentry_flutter/src/view_hierarchy/view_hierarchy_integration.dart';
import 'package:sentry_flutter/src/web/javascript_transport.dart';

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
  WebSessionIntegration,
];

final linuxWindowsAndWebIntegrations = [
  GenericAppStartIntegration,
];

final nonWebIntegrations = [
  OnErrorIntegration,
];

// These should be added to iOS and macOS
final iOsAndMacOsIntegrations = [
  LoadContextsIntegration,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late NativeChannelFixture native;

  setUp(() async {
    native = NativeChannelFixture();
    SentryFlutter.native = null;
  });

  group('Test platform integrations', () {
    setUp(() async {
      loadTestPackage();
      await Sentry.close();
      SentryFlutter.native = null;
    });

    test('iOS', () async {
      late final SentryFlutterOptions options;
      late final Transport transport;

      final sentryFlutterOptions =
          defaultTestOptions(checker: MockRuntimeChecker())
            ..platform = MockPlatform.iOS()
            ..methodChannel = native.channel;

      await SentryFlutter.init(
        (o) async {
          o.dsn = fakeDsn;
          o.profilesSampleRate = 1.0;
          options = o;
          transport = o.transport;
        },
        appRunner: appRunner,
        options: sentryFlutterOptions,
      );

      expect(transport, isA<FileSystemTransport>());

      testScopeObserver(
          options: sentryFlutterOptions, expectedHasNativeScopeObserver: true);

      testConfiguration(
        integrations: options.integrations,
        shouldHaveIntegrations: [
          ...iOsAndMacOsIntegrations,
          ...platformAgnosticIntegrations,
          ...nonWebIntegrations,
          ReplayIntegration,
        ],
        shouldNotHaveIntegrations: [
          ...nonWebIntegrations,
        ],
      );

      testBefore(
          integrations: options.integrations,
          beforeIntegration: WidgetsFlutterBindingIntegration,
          afterIntegration: OnErrorIntegration);

      expect(SentryFlutter.native, isNotNull);
      expect(Sentry.currentHub.profilerFactory,
          isInstanceOf<SentryNativeProfilerFactory>());

      expect(
          options.eventProcessors.indexOfTypeString('IoEnricherEventProcessor'),
          greaterThan(options.eventProcessors
              .indexOfTypeString('_LoadContextsIntegrationEventProcessor')));

      await Sentry.close();
    }, testOn: 'vm');

    test('macOS', () async {
      List<Integration> integrations = [];
      Transport transport = MockTransport();
      final sentryFlutterOptions =
          defaultTestOptions(checker: MockRuntimeChecker())
            ..platform = MockPlatform.macOS()
            ..methodChannel = native.channel;

      await SentryFlutter.init(
        (options) async {
          options.dsn = fakeDsn;
          options.profilesSampleRate = 1.0;
          integrations = options.integrations;
          transport = options.transport;
        },
        appRunner: appRunner,
        options: sentryFlutterOptions,
      );

      expect(transport, isA<FileSystemTransport>());

      testScopeObserver(
          options: sentryFlutterOptions, expectedHasNativeScopeObserver: true);

      testConfiguration(integrations: integrations, shouldHaveIntegrations: [
        ...iOsAndMacOsIntegrations,
        ...platformAgnosticIntegrations,
        ...nonWebIntegrations,
      ], shouldNotHaveIntegrations: [
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
      final sentryFlutterOptions =
          defaultTestOptions(checker: MockRuntimeChecker())
            ..platform = MockPlatform.windows()
            // We need to disable native init because sentry.dll is not available here.
            ..autoInitializeNativeSdk = false;

      await SentryFlutter.init(
        (options) async {
          options.dsn = fakeDsn;
          options.profilesSampleRate = 1.0;
          integrations = options.integrations;
          transport = options.transport;
        },
        appRunner: appRunner,
        options: sentryFlutterOptions,
      );

      expect(transport, isNot(isA<FileSystemTransport>()));

      testScopeObserver(
          options: sentryFlutterOptions, expectedHasNativeScopeObserver: true);

      testConfiguration(
        integrations: integrations,
        shouldHaveIntegrations: [
          ...platformAgnosticIntegrations,
          ...nonWebIntegrations,
          ...linuxWindowsAndWebIntegrations,
        ],
        shouldNotHaveIntegrations: [
          ...iOsAndMacOsIntegrations,
          ...webIntegrations,
        ],
      );

      testBefore(
          integrations: integrations,
          beforeIntegration: WidgetsFlutterBindingIntegration,
          afterIntegration: OnErrorIntegration);

      expect(SentryFlutter.native, isNotNull);
      expect(Sentry.currentHub.profilerFactory, isNull);
    }, testOn: 'vm');

    test('Linux', () async {
      List<Integration> integrations = [];
      Transport transport = MockTransport();
      final sentryFlutterOptions =
          defaultTestOptions(checker: MockRuntimeChecker())
            ..platform = MockPlatform.linux()
            ..methodChannel = native.channel
            // We need to disable native init because libsentry.so is not available here.
            ..autoInitializeNativeSdk = false;

      await SentryFlutter.init(
        (options) async {
          options.dsn = fakeDsn;
          options.profilesSampleRate = 1.0;
          integrations = options.integrations;
          transport = options.transport;
        },
        appRunner: appRunner,
        options: sentryFlutterOptions,
      );

      expect(transport, isNot(isA<FileSystemTransport>()));

      testScopeObserver(
          options: sentryFlutterOptions, expectedHasNativeScopeObserver: true);

      testConfiguration(
        integrations: integrations,
        shouldHaveIntegrations: [
          ...platformAgnosticIntegrations,
          ...nonWebIntegrations,
          ...linuxWindowsAndWebIntegrations,
        ],
        shouldNotHaveIntegrations: [
          ...iOsAndMacOsIntegrations,
          ...webIntegrations,
        ],
      );

      testBefore(
          integrations: integrations,
          beforeIntegration: WidgetsFlutterBindingIntegration,
          afterIntegration: OnErrorIntegration);

      expect(SentryFlutter.native, isNotNull);
      expect(Sentry.currentHub.profilerFactory, isNull);

      await Sentry.close();
    }, testOn: 'vm');

    test('Web', () async {
      List<Integration> integrations = [];
      Transport transport = MockTransport();
      final sentryFlutterOptions =
          defaultTestOptions(checker: MockRuntimeChecker())
            ..platform = MockPlatform.linux(isWeb: true)
            ..methodChannel = native.channel;

      await SentryFlutter.init(
        (options) async {
          options.profilesSampleRate = 1.0;
          integrations = options.integrations;
          transport = options.transport;
        },
        appRunner: appRunner,
        options: sentryFlutterOptions,
      );

      expect(transport, isA<JavascriptTransport>());

      testScopeObserver(
        options: sentryFlutterOptions,
        expectedHasNativeScopeObserver: false,
      );

      testConfiguration(
        integrations: integrations,
        shouldHaveIntegrations: [
          ...platformAgnosticIntegrations,
          ...webIntegrations,
          ...linuxWindowsAndWebIntegrations,
        ],
        shouldNotHaveIntegrations: [
          ...iOsAndMacOsIntegrations,
          ...nonWebIntegrations,
        ],
      );

      testBefore(
          integrations: Sentry.currentHub.options.integrations,
          beforeIntegration: RunZonedGuardedIntegration,
          afterIntegration: WidgetsFlutterBindingIntegration);

      expect(SentryFlutter.native, isNotNull);
      expect(Sentry.currentHub.profilerFactory, isNull);

      await Sentry.close();
    }, testOn: 'browser');

    test('Web (custom zone)', () async {
      final checker = MockRuntimeChecker(isRoot: false);
      final sentryFlutterOptions = defaultTestOptions(checker: checker)
        ..platform = MockPlatform.iOS(isWeb: true)
        ..methodChannel = native.channel;

      await SentryFlutter.init(
        (options) async {
          options.profilesSampleRate = 1.0;
        },
        appRunner: appRunner,
        options: sentryFlutterOptions,
      );

      final containsRunZonedGuardedIntegration =
          Sentry.currentHub.options.integrations.any(
        (integration) => integration is RunZonedGuardedIntegration,
      );
      expect(containsRunZonedGuardedIntegration, isFalse);

      expect(SentryFlutter.native, isNotNull);

      await Sentry.close();
    }, testOn: 'browser');

    test('Web && (iOS || macOS)', () async {
      List<Integration> integrations = [];
      Transport transport = MockTransport();
      final sentryFlutterOptions =
          defaultTestOptions(checker: MockRuntimeChecker())
            ..platform = MockPlatform.iOS(isWeb: true)
            ..methodChannel = native.channel;

      // Tests that iOS || macOS integrations aren't added on a browser which
      // runs on iOS or macOS
      await SentryFlutter.init(
        (options) async {
          integrations = options.integrations;
          transport = options.transport;
        },
        appRunner: appRunner,
        options: sentryFlutterOptions,
      );

      expect(transport, isA<JavascriptTransport>());

      testConfiguration(
        integrations: integrations,
        shouldHaveIntegrations: [
          ...platformAgnosticIntegrations,
          ...webIntegrations,
          ...linuxWindowsAndWebIntegrations,
        ],
        shouldNotHaveIntegrations: [
          ...iOsAndMacOsIntegrations,
          ...nonWebIntegrations,
        ],
      );

      testBefore(
          integrations: Sentry.currentHub.options.integrations,
          beforeIntegration: RunZonedGuardedIntegration,
          afterIntegration: WidgetsFlutterBindingIntegration);

      expect(SentryFlutter.native, isNotNull);

      await Sentry.close();
    }, testOn: 'browser');

    test('Web && (macOS)', () async {
      List<Integration> integrations = [];
      Transport transport = MockTransport();
      final sentryFlutterOptions =
          defaultTestOptions(checker: MockRuntimeChecker())
            ..platform = MockPlatform.macOS(isWeb: true)
            ..methodChannel = native.channel;

      // Tests that iOS || macOS integrations aren't added on a browser which
      // runs on iOS or macOS
      await SentryFlutter.init(
        (options) async {
          integrations = options.integrations;
          transport = options.transport;
        },
        appRunner: appRunner,
        options: sentryFlutterOptions,
      );

      expect(transport, isA<JavascriptTransport>());

      testConfiguration(
        integrations: integrations,
        shouldHaveIntegrations: [
          ...platformAgnosticIntegrations,
          ...webIntegrations,
          ...linuxWindowsAndWebIntegrations,
        ],
        shouldNotHaveIntegrations: [
          ...iOsAndMacOsIntegrations,
          ...nonWebIntegrations,
        ],
      );

      testBefore(
          integrations: Sentry.currentHub.options.integrations,
          beforeIntegration: RunZonedGuardedIntegration,
          afterIntegration: WidgetsFlutterBindingIntegration);

      expect(Sentry.currentHub.profilerFactory, isNull);
      expect(SentryFlutter.native, isNotNull);

      await Sentry.close();
    }, testOn: 'browser');
  });

  group('Test ScreenshotIntegration', () {
    setUp(() async {
      await Sentry.close();
    });

    test('installed on io platforms', () async {
      List<Integration> integrations = [];

      final sentryFlutterOptions =
          defaultTestOptions(checker: MockRuntimeChecker())
            ..platform = MockPlatform.iOS()
            ..methodChannel = native.channel
            ..rendererWrapper = MockRendererWrapper(FlutterRenderer.skia)
            ..release = ''
            ..dist = '';

      await SentryFlutter.init(
        (options) async {
          integrations = options.integrations;
        },
        appRunner: appRunner,
        options: sentryFlutterOptions,
      );

      expect(
          integrations
              .map((e) => e.runtimeType)
              .contains(ScreenshotIntegration),
          true);

      await Sentry.close();
    }, testOn: 'vm');

    test('installed on web with canvasKit renderer', () async {
      List<Integration> integrations = [];

      final sentryFlutterOptions =
          defaultTestOptions(checker: MockRuntimeChecker())
            ..platform = MockPlatform.iOS(isWeb: true)
            ..rendererWrapper = MockRendererWrapper(FlutterRenderer.canvasKit)
            ..release = ''
            ..dist = '';

      await SentryFlutter.init(
        (options) async {
          integrations = options.integrations;
        },
        appRunner: appRunner,
        options: sentryFlutterOptions,
      );

      expect(
          integrations
              .map((e) => e.runtimeType)
              .contains(ScreenshotIntegration),
          true);

      await Sentry.close();
    }, testOn: 'browser');

    test('installed on web with skwasm renderer', () async {
      List<Integration> integrations = [];

      final sentryFlutterOptions =
          defaultTestOptions(checker: MockRuntimeChecker())
            ..platform = MockPlatform.iOS(isWeb: true)
            ..rendererWrapper = MockRendererWrapper(FlutterRenderer.skwasm)
            ..release = ''
            ..dist = '';

      await SentryFlutter.init(
        (options) async {
          integrations = options.integrations;
        },
        appRunner: appRunner,
        options: sentryFlutterOptions,
      );

      expect(
          integrations
              .map((e) => e.runtimeType)
              .contains(ScreenshotIntegration),
          true);

      await Sentry.close();
    }, testOn: 'browser');

    test('not installed with html renderer', () async {
      List<Integration> integrations = [];

      final sentryFlutterOptions =
          defaultTestOptions(checker: MockRuntimeChecker())
            ..platform = MockPlatform.iOS(isWeb: true)
            ..rendererWrapper = MockRendererWrapper(FlutterRenderer.html)
            ..release = ''
            ..dist = '';

      await SentryFlutter.init(
        (options) async {
          integrations = options.integrations;
        },
        appRunner: appRunner,
        options: sentryFlutterOptions,
      );

      expect(
          integrations
              .map((e) => e.runtimeType)
              .contains(ScreenshotIntegration),
          false);

      await Sentry.close();
    }, testOn: 'browser');
  });

  group('initial values', () {
    setUp(() async {
      loadTestPackage();
    });

    tearDown(() async {
      await Sentry.close();
    });

    test('test that initial values are set correctly', () async {
      final sentryFlutterOptions =
          defaultTestOptions(checker: MockRuntimeChecker())
            ..platform = MockPlatform.iOS()
            ..methodChannel = native.channel;

      await SentryFlutter.init(
        (options) {
          expect(true, options.debug);
          expect('debug', options.environment);
          expect(sdkName, options.sdk.name);
          expect(sdkVersion, options.sdk.version);
          expect('pub:sentry_flutter', options.sdk.packages.last.name);
          expect(sdkVersion, options.sdk.packages.last.version);
        },
        appRunner: appRunner,
        options: sentryFlutterOptions,
      );
    });

    test(
        'enablePureDartSymbolication is set to false during SentryFlutter init',
        () async {
      final sentryFlutterOptions =
          defaultTestOptions(checker: MockRuntimeChecker())
            ..platform = MockPlatform.iOS()
            ..methodChannel = native.channel;

      SentryFlutter.native = mockNativeBinding();
      await SentryFlutter.init(
        (options) {
          expect(options.enableDartSymbolication, false);
        },
        appRunner: appRunner,
        options: sentryFlutterOptions,
      );
      SentryFlutter.native = null;
    });
  });

  test('resumeAppHangTracking calls native method when available', () async {
    SentryFlutter.native = mockNativeBinding();
    when(SentryFlutter.native?.resumeAppHangTracking())
        .thenAnswer((_) => Future.value());

    await SentryFlutter.resumeAppHangTracking();

    verify(SentryFlutter.native?.resumeAppHangTracking()).called(1);

    SentryFlutter.native = null;
  });

  test('resumeAppHangTracking does nothing when native is null', () async {
    SentryFlutter.native = null;

    // This should complete without throwing an error
    await expectLater(SentryFlutter.resumeAppHangTracking(), completes);
  });

  test('pauseAppHangTracking calls native method when available', () async {
    SentryFlutter.native = mockNativeBinding();
    when(SentryFlutter.native?.pauseAppHangTracking())
        .thenAnswer((_) => Future.value());

    await SentryFlutter.pauseAppHangTracking();

    verify(SentryFlutter.native?.pauseAppHangTracking()).called(1);

    SentryFlutter.native = null;
  });

  test('pauseAppHangTracking does nothing when native is null', () async {
    SentryFlutter.native = null;

    // This should complete without throwing an error
    await expectLater(SentryFlutter.pauseAppHangTracking(), completes);
  });

  group('exception identifiers', () {
    setUp(() async {
      loadTestPackage();
    });

    tearDown(() async {
      await Sentry.close();
    });

    test(
        'should add DartExceptionTypeIdentifier and FlutterExceptionTypeIdentifier by default',
        () async {
      final actualOptions = defaultTestOptions(checker: MockRuntimeChecker())
        ..platform = MockPlatform.iOS()
        ..methodChannel = native.channel;

      await SentryFlutter.init(
        (options) {},
        appRunner: appRunner,
        options: actualOptions,
      );

      expect(actualOptions.exceptionTypeIdentifiers.length, 2);
      // Flutter identifier should be first as it's more specific
      expect(
        actualOptions.exceptionTypeIdentifiers.first,
        isA<CachingExceptionTypeIdentifier>().having(
          (c) => c.identifier,
          'wrapped identifier',
          isA<FlutterExceptionTypeIdentifier>(),
        ),
      );
      expect(
        actualOptions.exceptionTypeIdentifiers[1],
        isA<CachingExceptionTypeIdentifier>().having(
          (c) => c.identifier,
          'wrapped identifier',
          isA<DartExceptionTypeIdentifier>(),
        ),
      );
    });
  });
}

MockSentryNativeBinding mockNativeBinding() {
  final result = MockSentryNativeBinding();
  when(result.supportsLoadContexts).thenReturn(true);
  when(result.supportsCaptureEnvelope).thenReturn(true);
  when(result.supportsReplay).thenReturn(false);
  when(result.captureEnvelope(any, any)).thenReturn(null);
  when(result.init(any)).thenReturn(null);
  when(result.close()).thenReturn(null);
  return result;
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
