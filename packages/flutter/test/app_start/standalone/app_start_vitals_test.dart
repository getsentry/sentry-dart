// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/app_start/app_start_timing.dart';
import 'package:sentry_flutter/src/app_start/standalone/app_start_trace.dart';
import 'package:sentry_flutter/src/app_start/standalone/app_start_vitals.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('$AppStartVitals', () {
    test('reports the duration from process start to the first frame', () {
      final vitals = fixture.resolve(
        endTimestamp:
            fixture.processStart.add(const Duration(milliseconds: 750)),
      );

      expect(vitals.duration, const Duration(milliseconds: 750));
    });

    test('reports type and screen', () {
      final vitals = fixture.resolve(
        type: AppStartType.warm,
        screen: 'MyHomePage',
        endTimestamp: fixture.processStart.add(const Duration(seconds: 1)),
      );

      expect(vitals.type, AppStartType.warm);
      expect(vitals.screen, 'MyHomePage');
    });

    test('returns null duration when no first frame arrived', () {
      final vitals = fixture.resolve(endTimestamp: null);

      expect(vitals.duration, isNull);
    });

    test('measures to an extension that outlasted the first frame', () {
      final vitals = fixture.resolve(
        endTimestamp:
            fixture.processStart.add(const Duration(milliseconds: 750)),
        extension: (
          isSettled: true,
          endTimestamp:
              fixture.processStart.add(const Duration(milliseconds: 1200)),
        ),
      );

      expect(vitals.duration, const Duration(milliseconds: 1200));
    });

    test('keeps the first frame when the extension ended before it', () {
      final vitals = fixture.resolve(
        endTimestamp:
            fixture.processStart.add(const Duration(milliseconds: 750)),
        extension: (
          isSettled: true,
          endTimestamp:
              fixture.processStart.add(const Duration(milliseconds: 400)),
        ),
      );

      expect(vitals.duration, const Duration(milliseconds: 750));
    });

    test('returns null duration while an extension is unsettled', () {
      final vitals = fixture.resolve(
        endTimestamp:
            fixture.processStart.add(const Duration(milliseconds: 750)),
        extension: (isSettled: false, endTimestamp: null),
      );

      expect(vitals.duration, isNull);
    });

    test('returns null duration when the root hit its deadline', () {
      final vitals = fixture.resolve(
        endTimestamp: fixture.processStart.add(const Duration(seconds: 1)),
        deadlineExceeded: true,
      );

      expect(vitals.duration, isNull);
    });

    test('still reports type and screen when the duration is absent', () {
      final vitals = fixture.resolve(
        type: AppStartType.warm,
        screen: 'MyHomePage',
        endTimestamp: null,
      );

      expect(vitals.type, AppStartType.warm);
      expect(vitals.screen, 'MyHomePage');
    });

    test('returns null duration when the window exceeds the plausible ceiling',
        () {
      final vitals = fixture.resolve(
        endTimestamp: fixture.processStart.add(const Duration(seconds: 61)),
      );

      expect(vitals.duration, isNull);
    });

    test('returns null duration when the first frame precedes process start',
        () {
      final vitals = fixture.resolve(
        endTimestamp: fixture.processStart.subtract(const Duration(seconds: 1)),
      );

      expect(vitals.duration, isNull);
    });

    group('measurement', () {
      test('is a cold app start on a cold launch', () {
        final vitals = fixture.resolve(
          endTimestamp: fixture.processStart.add(const Duration(seconds: 1)),
        );

        expect(vitals.measurement?.name, 'app_start_cold');
        expect(vitals.measurement?.value, 1000);
      });

      test('is a warm app start on a warm launch', () {
        final vitals = fixture.resolve(
          type: AppStartType.warm,
          endTimestamp: fixture.processStart.add(const Duration(seconds: 1)),
        );

        expect(vitals.measurement?.name, 'app_start_warm');
      });

      test('returns null when the duration is absent', () {
        final vitals = fixture.resolve(endTimestamp: null);

        expect(vitals.measurement, isNull);
      });
    });

    group('durationAttributeKey', () {
      test('is the cold key on a cold launch', () {
        final vitals = fixture.resolve(
          endTimestamp: fixture.processStart.add(const Duration(seconds: 1)),
        );

        expect(vitals.durationAttributeKey, 'app.vitals.start.cold.value');
      });

      test('is the warm key on a warm launch', () {
        final vitals = fixture.resolve(
          type: AppStartType.warm,
          endTimestamp: fixture.processStart.add(const Duration(seconds: 1)),
        );

        expect(vitals.durationAttributeKey, 'app.vitals.start.warm.value');
      });
    });
  });
}

class Fixture {
  final processStart = DateTime.utc(2024, 1, 15, 12, 0, 0);

  AppStartTiming timing({AppStartType type = AppStartType.cold}) =>
      AppStartTiming(
        type: type,
        processStartTimestamp: processStart,
        pluginRegistrationTimestamp:
            processStart.add(const Duration(milliseconds: 100)),
        sentrySetupTimestamp:
            processStart.add(const Duration(milliseconds: 200)),
        phases: [],
      );

  AppStartVitals resolve({
    AppStartType type = AppStartType.cold,
    String screen = 'root /',
    required DateTime? endTimestamp,
    AppStartExtensionOutcome extension = noAppStartExtension,
    bool deadlineExceeded = false,
  }) =>
      AppStartVitals.resolve(
        timing: timing(type: type),
        screen: screen,
        endTimestamp: endTimestamp,
        extension: extension,
        deadlineExceeded: deadlineExceeded,
      );
}
