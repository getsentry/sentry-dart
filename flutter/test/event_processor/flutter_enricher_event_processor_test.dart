import 'dart:async';

import 'package:flutter/foundation.dart';

// backcompatibility for Flutter < 3.3
// ignore: unnecessary_import
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/event_processor/flutter_enricher_event_processor.dart';

import '../mocks.dart';

void main() {
  group(FlutterEnricherEventProcessor, () {
    late Fixture fixture;

    setUp(() async {
      await Sentry.close();

      LicenseRegistry.reset();
      fixture = Fixture();
    });

    testWidgets('flutter context on dart:io', (WidgetTester tester) async {
      if (kIsWeb) {
        // widget tests don't support onPlatform config
        // https://pub.dev/packages/test#platform-specific-configuration
        return;
      }
      // These two values need to be changed inside the test,
      // otherwise the Flutter test framework complains that these
      // values are changed outside of a test.
      debugBrightnessOverride = Brightness.dark;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final enricher = fixture.getSut(
        binding: () => tester.binding,
      );

      final event = await enricher.apply(SentryEvent(), Hint());

      debugBrightnessOverride = null;
      debugDefaultTargetPlatformOverride = null;

      final flutterContext = event?.contexts['flutter_context'];
      expect(flutterContext, isNotNull);
      expect(flutterContext, isA<Map<String, String>>());
    }, skip: !kIsWeb);

    testWidgets('flutter context on web', (WidgetTester tester) async {
      if (!kIsWeb) {
        // widget tests don't support onPlatform config
        // https://pub.dev/packages/test#platform-specific-configuration
        return;
      }

      // These two values need to be changed inside the test,
      // otherwise the Flutter test framework complains that these
      // values are changed outside of a test.
      debugBrightnessOverride = Brightness.dark;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final enricher = fixture.getSut(
        binding: () => tester.binding,
      );

      final event = await enricher.apply(SentryEvent(), Hint());

      debugBrightnessOverride = null;
      debugDefaultTargetPlatformOverride = null;

      final flutterContext = event?.contexts['flutter_context'];
      expect(flutterContext, isNotNull);
      expect(flutterContext, isA<Map<String, String>>());
      expect(flutterContext['renderer'], isNotNull);
    });

    testWidgets('accessibility context', (WidgetTester tester) async {
      final enricher = fixture.getSut(
        binding: () => tester.binding,
      );

      final event = await enricher.apply(SentryEvent(), Hint());

      final accessibility = event?.contexts['accessibility'];

      expect(accessibility['accessible_navigation'], isNotNull);
      expect(accessibility['bold_text'], isNotNull);
      expect(accessibility['disable_animations'], isNotNull);
      expect(accessibility['high_contrast'], isNotNull);
      expect(accessibility['invert_colors'], isNotNull);
      expect(accessibility['reduce_motion'], isNotNull);
    });

    testWidgets('culture context', (WidgetTester tester) async {
      final enricher = fixture.getSut(
        binding: () => tester.binding,
      );

      final event = await enricher.apply(SentryEvent(), Hint());

      final culture = event?.contexts.culture;

      expect(culture?.is24HourFormat, isNotNull);
      expect(culture?.timezone, isNotNull);
    });

    testWidgets(
        'GIVEN MaterialApp WHEN setting locale and sentryNavigatorKey THEN enrich event culture with selected locale',
        (WidgetTester tester) async {
      GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: Material(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', 'US'),
          Locale('de', 'DE'),
        ],
        locale: const Locale('de', 'DE'),
      ));

      final enricher = fixture.getSut(
        binding: () => tester.binding,
        optionsBuilder: (options) {
          options.navigatorKey = navigatorKey;
          return options;
        },
      );

      final event = await enricher.apply(SentryEvent(), Hint());

      expect(event?.contexts.culture?.locale, 'de-DE');
    });

    testWidgets('app context in foreground', (WidgetTester tester) async {
      final enricher = fixture.getSut(
        binding: () => tester.binding,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final event = await enricher.apply(SentryEvent(), Hint());

      final app = event?.contexts.app;

      expect(app?.inForeground, true);
    });

    testWidgets('app context not in foreground', (WidgetTester tester) async {
      final enricher = fixture.getSut(
        binding: () => tester.binding,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      final event = await enricher.apply(SentryEvent(), Hint());

      final app = event?.contexts.app;

      expect(app?.inForeground, false);
    });

    testWidgets('merge app context in foreground', (WidgetTester tester) async {
      final enricher = fixture.getSut(
        binding: () => tester.binding,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      const appName = 'My App';
      final event = SentryEvent();
      event.contexts.app = SentryApp(name: appName);

      final mutatedEvent = await enricher.apply(event, Hint());

      final app = mutatedEvent?.contexts.app;

      expect(app?.inForeground, true);
      expect(app?.name, appName);
    });

    testWidgets('no device when native integration is available',
        (WidgetTester tester) async {
      final enricher = fixture.getSut(
        binding: () => tester.binding,
        hasNativeIntegration: true,
      );

      final event = await enricher.apply(SentryEvent(), Hint());

      expect(event?.contexts.device, isNull);
    });

    testWidgets('has device when native integration is not available',
        (WidgetTester tester) async {
      final enricher = fixture.getSut(
        binding: () => tester.binding,
        hasNativeIntegration: false,
      );

      final event = await enricher.apply(SentryEvent(), Hint());

      expect(event?.contexts.device, isNotNull);
    });

    testWidgets('adds flutter runtime', (WidgetTester tester) async {
      final enricher = fixture.getSut(
        binding: () => tester.binding,
      );

      final event = await enricher.apply(SentryEvent(), Hint());

      final flutterRuntime = event?.contexts.runtimes
          .firstWhere((element) => element.name == 'Flutter');
      expect(flutterRuntime?.name, 'Flutter');
      expect(flutterRuntime?.compiler, isNotNull);
    });

    testWidgets('adds correct flutter runtime', (WidgetTester tester) async {
      final checkerMap = {
        MockPlatformChecker(isWebValue: false, isDebug: true): 'Dart VM',
        MockPlatformChecker(isWebValue: false, isProfile: true): 'Dart AOT',
        MockPlatformChecker(isWebValue: false, isRelease: true): 'Dart AOT',
        MockPlatformChecker(isWebValue: true, isDebug: true): 'dartdevc',
        MockPlatformChecker(isWebValue: true, isProfile: true): 'dart2js',
        MockPlatformChecker(isWebValue: true, isRelease: true): 'dart2js',
      };

      for (var pair in checkerMap.entries) {
        final enricher = fixture.getSut(
          binding: () => tester.binding,
          checker: pair.key,
        );

        final event = await enricher.apply(SentryEvent(), Hint());
        final flutterRuntime = event?.contexts.runtimes
            .firstWhere((element) => element.name == 'Flutter');

        expect(flutterRuntime?.name, 'Flutter');
        expect(flutterRuntime?.compiler, pair.value);
      }
    });

    testWidgets('adds packages', (WidgetTester tester) async {
      final enricher = fixture.getSut(
        binding: () => tester.binding,
      );

      LicenseRegistry.addLicense(
        () => Stream.fromIterable(
          [
            LicenseEntryWithLineBreaks(
              [
                'foo_package',
                'bar_package',
              ],
              'Test License Text',
            ),
          ],
        ),
      );

      final event = await enricher.apply(SentryEvent(), Hint());

      expect(event?.modules, {
        'foo_package': 'unknown',
        'bar_package': 'unknown',
      });
    });

    testWidgets('do no add packages if disabled', (WidgetTester tester) async {
      final enricher = fixture.getSut(
        binding: () => tester.binding,
        reportPackages: false,
      );

      LicenseRegistry.addLicense(
        () => Stream.fromIterable(
          [
            LicenseEntryWithLineBreaks(
              [
                'foo_package',
                'bar_package',
              ],
              'Test License Text',
            ),
          ],
        ),
      );

      final event = await enricher.apply(SentryEvent(), Hint());

      expect(event?.modules, null);
    });

    testWidgets('adds packages only once', (WidgetTester tester) async {
      final enricher = fixture.getSut(
        binding: () => tester.binding,
      );

      LicenseRegistry.addLicense(
        () => Stream.fromIterable(
          [
            LicenseEntryWithLineBreaks(
              [
                'foo_package',
                'foo_package',
              ],
              'Test License Text',
            ),
          ],
        ),
      );

      final event = await enricher.apply(SentryEvent(), Hint());

      expect(event?.modules, {'foo_package': 'unknown'});
    });

    testWidgets('does not override event', (WidgetTester tester) async {
      final fakeEvent = SentryEvent(
        contexts: Contexts(
          device: SentryDevice(
            orientation: SentryOrientation.landscape,
            screenHeightPixels: 1080,
            screenWidthPixels: 1920,
            screenDensity: 2,
          ),
          operatingSystem: SentryOperatingSystem(
            theme: 'dark',
          ),
        ),
      );

      final enricher = fixture.getSut(
        binding: () => tester.binding,
        hasNativeIntegration: false,
      );

      final event = await enricher.apply(fakeEvent, Hint());

      // contexts.device
      expect(
        event?.contexts.device?.orientation,
        fakeEvent.contexts.device?.orientation,
      );
      expect(
        event?.contexts.device?.screenHeightPixels,
        fakeEvent.contexts.device?.screenHeightPixels,
      );
      expect(
        event?.contexts.device?.screenWidthPixels,
        fakeEvent.contexts.device?.screenWidthPixels,
      );
      expect(
        event?.contexts.device?.screenDensity,
        fakeEvent.contexts.device?.screenDensity,
      );
      expect(
        event?.contexts.operatingSystem?.theme,
        fakeEvent.contexts.operatingSystem?.theme,
      );
    });

    testWidgets('$FlutterEnricherEventProcessor gets added on init',
        (tester) async {
      // use a mockplatform checker so that we don't need to mock platform channels
      final sentryOptions =
          defaultTestOptions(MockPlatformChecker(hasNativeIntegration: false));

      loadTestPackage();
      await SentryFlutter.init((options) {
        options.dsn = fakeDsn;
      }, appRunner: () {}, options: sentryOptions);
      await Sentry.close();

      final ioEnricherCount = sentryOptions.eventProcessors
          .whereType<FlutterEnricherEventProcessor>()
          .length;
      expect(ioEnricherCount, 1);
    });

    testWidgets('adds SentryNavigatorObserver.currentRouteName as app.screen',
        (tester) async {
      final observer = SentryNavigatorObserver();
      final route =
          fixture.route(RouteSettings(name: 'fixture-currentRouteName'));
      observer.didPush(route, null);

      final eventWithContextsApp =
          SentryEvent(contexts: Contexts(app: SentryApp()));

      final enricher = fixture.getSut(
        binding: () => tester.binding,
      );
      final event = await enricher.apply(eventWithContextsApp, Hint());

      expect(event?.contexts.app?.viewNames, ['fixture-currentRouteName']);
    });
  });
}

class Fixture {
  FlutterEnricherEventProcessor getSut({
    required WidgetBindingGetter binding,
    PlatformChecker? checker,
    bool hasNativeIntegration = false,
    bool reportPackages = true,
    SentryFlutterOptions Function(SentryFlutterOptions)? optionsBuilder,
  }) {
    final platformChecker = checker ??
        MockPlatformChecker(
          hasNativeIntegration: hasNativeIntegration,
        );

    final options = defaultTestOptions(platformChecker)
      ..reportPackages = reportPackages;
    final customizedOptions = optionsBuilder?.call(options) ?? options;
    return FlutterEnricherEventProcessor(customizedOptions);
  }

  PageRoute<dynamic> route(RouteSettings? settings) => PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => Container(),
        settings: settings,
      );
}

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
