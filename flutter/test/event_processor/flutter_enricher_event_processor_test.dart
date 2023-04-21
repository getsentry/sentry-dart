import 'dart:async';

import 'package:flutter/foundation.dart';
// backcompatibility for Flutter < 3.3
// ignore: unnecessary_import
import 'package:flutter/material.dart';
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

    testWidgets('flutter context', (WidgetTester tester) async {
      // These two values need to be changed inside the test,
      // otherwise the Flutter test framework complains that these
      // values are changed outside of a test.
      debugBrightnessOverride = Brightness.dark;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final enricher = fixture.getSut(
        binding: () => tester.binding,
      );

      final event = await enricher.apply(SentryEvent());

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

      final event = await enricher.apply(SentryEvent());

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

      final event = await enricher.apply(SentryEvent());

      final culture = event?.contexts.culture;

      expect(culture?.is24HourFormat, isNotNull);
      expect(culture?.timezone, isNotNull);
    });

    testWidgets('app context in foreground', (WidgetTester tester) async {
      final enricher = fixture.getSut(
        binding: () => tester.binding,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final event = await enricher.apply(SentryEvent());

      final app = event?.contexts.app;

      expect(app?.inForeground, true);
    });

    testWidgets('app context not in foreground', (WidgetTester tester) async {
      final enricher = fixture.getSut(
        binding: () => tester.binding,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      final event = await enricher.apply(SentryEvent());

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

      final mutatedEvent = await enricher.apply(event);

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

      final event = await enricher.apply(SentryEvent());

      expect(event?.contexts.device, isNull);
    });

    testWidgets('has device when native integration is not available',
        (WidgetTester tester) async {
      final enricher = fixture.getSut(
        binding: () => tester.binding,
        hasNativeIntegration: false,
      );

      final event = await enricher.apply(SentryEvent());

      expect(event?.contexts.device, isNotNull);
    });

    testWidgets('adds flutter runtime', (WidgetTester tester) async {
      final enricher = fixture.getSut(
        binding: () => tester.binding,
      );

      final event = await enricher.apply(SentryEvent());

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

        final event = await enricher.apply(SentryEvent());
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

      final event = await enricher.apply(SentryEvent());

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

      final event = await enricher.apply(SentryEvent());

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

      final event = await enricher.apply(SentryEvent());

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

      final event = await enricher.apply(fakeEvent);

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
      late SentryFlutterOptions sentryOptions;
      loadTestPackage();
      await SentryFlutter.init((options) {
        options.dsn = fakeDsn;
        sentryOptions = options;
      },
          appRunner: () {},
          // use a mockplatform checker so that
          // we don't need to mock platform channels
          platformChecker: MockPlatformChecker(
            hasNativeIntegration: false,
          ));
      await Sentry.close();

      final ioEnricherCount = sentryOptions.eventProcessors
          .whereType<FlutterEnricherEventProcessor>()
          .length;
      expect(ioEnricherCount, 1);
    });
  });
}

class Fixture {
  FlutterEnricherEventProcessor getSut({
    required WidgetBindingGetter binding,
    PlatformChecker? checker,
    bool hasNativeIntegration = false,
    bool reportPackages = true,
  }) {
    final platformChecker = checker ??
        MockPlatformChecker(
          hasNativeIntegration: hasNativeIntegration,
        );
    final options = SentryFlutterOptions(
      dsn: fakeDsn,
      checker: platformChecker,
    )..reportPackages = reportPackages;
    return FlutterEnricherEventProcessor(options);
  }
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
