import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/app_start/app_start_data.dart';
import 'package:sentry_flutter/src/app_start/native_app_start_parser.dart';
import 'package:sentry_flutter/src/native/native_app_start.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('parseNativeAppStart', () {
    test('returns info with cold type and sorted native spans', () {
      final info = parseNativeAppStart(
        fixture.nativeAppStart,
        fixture.appStartEnd,
      );

      expect(info, isNotNull);
      expect(info!.snapshot.type, AppStartType.cold);
      expect(
        info.snapshot.processStartTimestamp,
        DateTime.fromMillisecondsSinceEpoch(0),
      );
      expect(info.endTimestamp, fixture.appStartEnd);
      expect(
        info.snapshot.nativePhaseIntervals.map((s) => s.description),
        ['native span 1', 'native span 2'],
      );
    });

    test('returns null when app start duration exceeds 60s', () {
      final info = parseNativeAppStart(
        fixture.nativeAppStart,
        DateTime.fromMillisecondsSinceEpoch(60001),
      );

      expect(info, isNull);
    });

    test('returns null when sentry setup start time is missing', () {
      SentryFlutter.sentrySetupStartTime = null;

      final info = parseNativeAppStart(
        fixture.nativeAppStart,
        fixture.appStartEnd,
      );

      expect(info, isNull);
    });
  });
}

class Fixture {
  final appStartEnd = DateTime.fromMillisecondsSinceEpoch(50);

  final nativeAppStart = NativeAppStart(
    appStartTime: 0,
    pluginRegistrationTime: 10,
    isColdStart: true,
    nativeSpanTimes: {
      'native span 2': {
        'startTimestampMsSinceEpoch': 3,
        'stopTimestampMsSinceEpoch': 4,
      },
      'native span 1': {
        'startTimestampMsSinceEpoch': 1,
        'stopTimestampMsSinceEpoch': 2,
      },
    },
  );

  Fixture() {
    SentryFlutter.sentrySetupStartTime = DateTime.fromMillisecondsSinceEpoch(
      15,
    );
  }
}
