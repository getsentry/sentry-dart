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

    test('caps native phases at the span limit, keeping the earliest', () {
      fixture.nativeSpanTimes = fixture.buildNativeSpanTimes(5);

      final data = fixture.parse(maxNativePhases: 2);

      expect(
        data!.nativePhases.map((phase) => phase.description),
        ['phase 0', 'phase 1'],
      );
    });
  });
}

class Fixture {
  final processStart = DateTime.utc(2024, 1, 1, 12);
  late final pluginRegistration = processStart.add(Duration(milliseconds: 100));
  late final sentrySetup = processStart.add(Duration(milliseconds: 200));
  late final validUntil = processStart.add(Duration(milliseconds: 300));

  /// Native phases keyed newest-first, so a correct parse has to sort rather
  /// than lean on insertion order.
  Map<dynamic, dynamic> buildNativeSpanTimes(int count) => {
        for (var i = count - 1; i >= 0; i--)
          'phase $i': {
            'startTimestampMsSinceEpoch': processStart
                .add(Duration(milliseconds: 10 + i))
                .millisecondsSinceEpoch,
            'stopTimestampMsSinceEpoch': processStart
                .add(Duration(milliseconds: 11 + i))
                .millisecondsSinceEpoch,
          },
      };

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
    int maxNativePhases = 1000,
  }) =>
      AppStartTiming.tryParseAtFirstFrame(
        NativeAppStart(
          appStartTime: (appStartTime ?? processStart).millisecondsSinceEpoch,
          pluginRegistrationTime:
              (pluginRegistration ?? this.pluginRegistration)
                  .millisecondsSinceEpoch,
          isColdStart: true,
          nativeSpanTimes: nativeSpanTimes,
        ),
        sentrySetupTimestamp: sentrySetup ?? this.sentrySetup,
        firstFrameTimestamp: validUntil,
        maxNativePhases: maxNativePhases,
      );
}
