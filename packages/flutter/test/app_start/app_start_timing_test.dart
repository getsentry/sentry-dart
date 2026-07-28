import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/app_start/app_start_timing.dart';
import 'package:sentry_flutter/src/native/native_app_start.dart';

void main() {
  group('$AppStartTiming parsing', () {
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

    test('returns null when plugin registration precedes process start', () {
      final data = fixture.parse(
        pluginRegistration: fixture.processStart.subtract(
          Duration(milliseconds: 1),
        ),
      );

      expect(data, isNull);
    });

    test('returns null when setup precedes plugin registration', () {
      final data = fixture.parse(
        sentrySetup: fixture.pluginRegistration.subtract(
          Duration(milliseconds: 1),
        ),
      );

      expect(data, isNull);
    });

    test('discards one malformed optional phase', () {
      fixture.nativeSpanTimes['invalid'] = {
        'startTimestampMsSinceEpoch': fixture.firstFrame.millisecondsSinceEpoch,
        'stopTimestampMsSinceEpoch':
            fixture.processStart.millisecondsSinceEpoch,
      };

      final data = fixture.parse();

      expect(
        data!.nativePhases.map((phase) => phase.description),
        ['early', 'late'],
      );
    });

    test('discards optional phases starting before process start', () {
      fixture.nativeSpanTimes['before-process-start'] = {
        'startTimestampMsSinceEpoch': fixture.processStart
            .subtract(Duration(milliseconds: 2))
            .millisecondsSinceEpoch,
        'stopTimestampMsSinceEpoch': fixture.processStart
            .subtract(Duration(milliseconds: 1))
            .millisecondsSinceEpoch,
      };

      final data = fixture.parse();

      expect(
        data!.nativePhases.map((phase) => phase.description),
        ['early', 'late'],
      );
    });
  });

  group('$AppStartTiming reportable duration', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('returns the duration up to the given end', () {
      final timing = fixture.parse()!;

      expect(
        timing.reportableDurationUntil(fixture.firstFrame),
        Duration(milliseconds: 300),
      );
    });

    test('returns null when longer than sixty seconds', () {
      final timing = fixture.parse()!;

      final duration = timing.reportableDurationUntil(
        fixture.processStart.add(Duration(seconds: 61)),
      );

      expect(duration, isNull);
    });

    test('returns null when the end precedes process start', () {
      final timing = fixture.parse()!;

      final duration = timing.reportableDurationUntil(
        fixture.processStart.subtract(Duration(milliseconds: 1)),
      );

      expect(duration, isNull);
    });
  });
}

class Fixture {
  final processStart = DateTime.utc(2024, 1, 1, 12);
  late final pluginRegistration = processStart.add(Duration(milliseconds: 100));
  late final sentrySetup = processStart.add(Duration(milliseconds: 200));
  late final firstFrame = processStart.add(Duration(milliseconds: 300));

  /// Keyed newest-first, so a correct parse has to sort rather than lean on
  /// insertion order.
  late Map<dynamic, dynamic> nativeSpanTimes = <dynamic, dynamic>{
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

  AppStartTiming? parse({
    DateTime? appStartTime,
    DateTime? pluginRegistration,
    DateTime? sentrySetup,
  }) =>
      AppStartTiming.tryParse(
        NativeAppStart(
          appStartTime: (appStartTime ?? processStart).millisecondsSinceEpoch,
          pluginRegistrationTime:
              (pluginRegistration ?? this.pluginRegistration)
                  .millisecondsSinceEpoch,
          isColdStart: true,
          nativeSpanTimes: nativeSpanTimes,
        ),
        sentrySetupTimestamp: sentrySetup ?? this.sentrySetup,
      );
}
