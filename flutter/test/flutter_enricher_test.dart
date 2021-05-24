import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/src/platform/platform.dart';
import 'package:sentry/src/enricher/enricher.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('FlutterEnricher', () {
    late Fixture fixture;

    setUp(() {
      LicenseRegistry.reset();
      fixture = Fixture();
    });

    testWidgets('FlutterEnricher calls base Enricher',
        (WidgetTester tester) async {
      final enricher = fixture.getSut(
        binding: () => tester.binding,
        enricher: fixture.mockEnricher,
      );

      enricher.apply(fixture.event, true);

      expect(fixture.mockEnricher.calls.length, 1);
      expect(fixture.mockEnricher.calls.first.event, fixture.event);
      expect(fixture.mockEnricher.calls.first.hasNativeIntegration, true);
    });

    testWidgets('flutter context', (WidgetTester tester) async {
      final enricher = fixture.getSut(
        binding: () => tester.binding,
      );

      final event = await enricher.apply(fixture.event, false);

      final flutterContext = event.contexts['flutter_context'];
      expect(flutterContext, isNotNull);
    });

    testWidgets('accessibility context', (WidgetTester tester) async {
      final enricher = fixture.getSut(
        binding: () => tester.binding,
      );

      final event = await enricher.apply(fixture.event, false);

      final accessibility = event.contexts['accessibility'];

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

      final event = await enricher.apply(fixture.event, false);

      final culture = event.contexts['culture'];

      expect(culture['is_24_hour_format'], isNotNull);
      expect(culture['timezone'], isNotNull);
    });

    testWidgets('no device when native integration is available',
        (WidgetTester tester) async {
      final enricher = fixture.getSut(
        binding: () => tester.binding,
      );

      final event = await enricher.apply(fixture.event, true);

      expect(event.contexts.device, isNull);
    });

    testWidgets('has device when native integration is not available',
        (WidgetTester tester) async {
      final enricher = fixture.getSut(
        binding: () => tester.binding,
      );

      final event = await enricher.apply(fixture.event, false);

      expect(event.contexts.device, isNotNull);
    });

    testWidgets('adds flutter runtime', (WidgetTester tester) async {
      final enricher = fixture.getSut(
        binding: () => tester.binding,
      );

      final event = await enricher.apply(fixture.event, false);

      final flutterRuntime = event.contexts.runtimes
          .firstWhere((element) => element.name == 'Flutter');
      expect(flutterRuntime.name, 'Flutter');
      expect(flutterRuntime.compiler, isNotNull);
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

        final event = await enricher.apply(SentryEvent(), false);
        final flutterRuntime = event.contexts.runtimes
            .firstWhere((element) => element.name == 'Flutter');

        expect(flutterRuntime.name, 'Flutter');
        expect(flutterRuntime.compiler, pair.value);
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

      final event = await enricher.apply(fixture.event, false);

      expect(event.modules, {
        'foo_package': 'unknown',
        'bar_package': 'unknown',
      });
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

      final event = await enricher.apply(fixture.event, false);

      expect(event.modules, {'foo_package': 'unknown'});
    });
  });
}

class Fixture {
  final mockEnricher = MockEnricher();
  final event = SentryEvent();
  FlutterEnricher getSut({
    required WidgetBindingGetter binding,
    PlatformChecker? checker,
    Enricher? enricher,
  }) {
    return FlutterEnricher(
      checker ?? PlatformChecker(),
      enricher ?? NoopEnricher(),
      binding,
    );
  }
}

class MockEnricher implements Enricher {
  final List<ApplyCalls> calls = [];

  @override
  FutureOr<SentryEvent> apply(SentryEvent event, bool hasNativeIntegration) {
    calls.add(ApplyCalls(event, hasNativeIntegration));
    return event;
  }
}

class ApplyCalls {
  ApplyCalls(this.event, this.hasNativeIntegration);

  final SentryEvent event;
  final bool hasNativeIntegration;
}

class MockPlatformChecker implements PlatformChecker {
  MockPlatformChecker({
    this.isDebug = false,
    this.isProfile = false,
    this.isRelease = false,
    this.isWebValue = false,
  });

  final bool isDebug;
  final bool isProfile;
  final bool isRelease;
  final bool isWebValue;

  @override
  bool get hasNativeIntegration => false;

  @override
  bool isDebugMode() => isDebug;

  @override
  bool isProfileMode() => isProfile;

  @override
  bool isReleaseMode() => isRelease;

  @override
  bool get isWeb => isWebValue;

  @override
  Platform get platform => throw UnimplementedError();
}
