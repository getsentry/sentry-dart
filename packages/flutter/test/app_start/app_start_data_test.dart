import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/app_start/app_start_data.dart';
import 'package:sentry_flutter/src/native/native_app_start.dart';

void main() {
  group('$AppStartData.tryParse', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('parses intrinsic timing and sorts valid phases', () {
      final data = fixture.parse();

      expect(data, isNotNull);
      expect(data!.type, AppStartType.cold);
      expect(
        data.nativePhases.map((phase) => phase.description),
        ['early', 'late'],
      );
    });

    test('returns null for a future process start', () {
      final data = fixture.parse(
        appStartTime: fixture.validUntil.add(Duration(seconds: 1)),
      );

      expect(data, isNull);
    });

    test('returns null when older than sixty seconds', () {
      final data = fixture.parse(
        appStartTime: fixture.validUntil.subtract(Duration(seconds: 61)),
      );

      expect(data, isNull);
    });

    test('returns null for invalid root ordering', () {
      final data = fixture.parse(
        pluginRegistration: fixture.processStart.subtract(
          Duration(milliseconds: 1),
        ),
      );

      expect(data, isNull);
    });

    test('returns null when setup is after validUntil', () {
      final data = fixture.parse(
        sentrySetup: fixture.validUntil.add(Duration(milliseconds: 1)),
      );

      expect(data, isNull);
    });

    test('discards one malformed optional phase', () {
      fixture.nativeSpanTimes['invalid'] = {
        'startTimestampMsSinceEpoch': fixture.validUntil.millisecondsSinceEpoch,
        'stopTimestampMsSinceEpoch':
            fixture.processStart.millisecondsSinceEpoch,
      };

      final data = fixture.parse();

      expect(
        data!.nativePhases.map((phase) => phase.description),
        ['early', 'late'],
      );
    });

    test('discards optional phases outside the timing window', () {
      fixture.nativeSpanTimes.addAll({
        'before-process-start': {
          'startTimestampMsSinceEpoch': fixture.processStart
              .subtract(Duration(milliseconds: 2))
              .millisecondsSinceEpoch,
          'stopTimestampMsSinceEpoch': fixture.processStart
              .subtract(Duration(milliseconds: 1))
              .millisecondsSinceEpoch,
        },
        'after-valid-until': {
          'startTimestampMsSinceEpoch': fixture.validUntil
              .add(Duration(milliseconds: 1))
              .millisecondsSinceEpoch,
          'stopTimestampMsSinceEpoch': fixture.validUntil
              .add(Duration(milliseconds: 2))
              .millisecondsSinceEpoch,
        },
      });

      final data = fixture.parse();

      expect(
        data!.nativePhases.map((phase) => phase.description),
        ['early', 'late'],
      );
    });
  });
}

class Fixture {
  final processStart = DateTime.utc(2024, 1, 1, 12);
  late final pluginRegistration = processStart.add(Duration(milliseconds: 100));
  late final sentrySetup = processStart.add(Duration(milliseconds: 200));
  late final validUntil = processStart.add(Duration(milliseconds: 300));
  late final nativeSpanTimes = <dynamic, dynamic>{
    'late': {
      'startTimestampMsSinceEpoch':
          processStart.add(Duration(milliseconds: 50)).millisecondsSinceEpoch,
      'stopTimestampMsSinceEpoch':
          processStart.add(Duration(milliseconds: 60)).millisecondsSinceEpoch,
    },
    'early': {
      'startTimestampMsSinceEpoch':
          processStart.add(Duration(milliseconds: 10)).millisecondsSinceEpoch,
      'stopTimestampMsSinceEpoch':
          processStart.add(Duration(milliseconds: 20)).millisecondsSinceEpoch,
    },
  };

  AppStartData? parse({
    DateTime? appStartTime,
    DateTime? pluginRegistration,
    DateTime? sentrySetup,
  }) =>
      AppStartData.tryParse(
        NativeAppStart(
          appStartTime: (appStartTime ?? processStart).millisecondsSinceEpoch,
          pluginRegistrationTime:
              (pluginRegistration ?? this.pluginRegistration)
                  .millisecondsSinceEpoch,
          isColdStart: true,
          nativeSpanTimes: nativeSpanTimes,
        ),
        sentrySetupTimestamp: sentrySetup ?? this.sentrySetup,
        validUntil: validUntil,
      );
}
