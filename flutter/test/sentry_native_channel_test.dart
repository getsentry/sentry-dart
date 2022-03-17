import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/sentry_native.dart';
import 'package:sentry_flutter/src/sentry_native_channel.dart';
import 'mocks.mocks.dart';

void main() {
  group('$SentryNative', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('fetchNativeAppStart', () async {
      final map = <String, dynamic>{
        'appStartTime': 0.1,
        'isColdStart': true,
      };
      final future = Future.value(map);

      when(fixture.methodChannel
              .invokeMapMethod<String, dynamic>('fetchNativeAppStart'))
          .thenAnswer((_) => future);

      final sut = fixture.getSut();
      final actual = await sut.fetchNativeAppStart();

      expect(actual?.appStartTime, 0.1);
      expect(actual?.isColdStart, true);
    });

    test('beginNativeFrames', () async {
      final sut = fixture.getSut();
      await sut.beginNativeFrames();

      verify(fixture.methodChannel
          .invokeMapMethod<String, dynamic>('beginNativeFrames'));
    });

    test('endNativeFrames', () async {
      final sentryId = SentryId.empty();
      final map = <String, dynamic>{
        'totalFrames': 3,
        'slowFrames': 2,
        'frozenFrames': 1
      };
      final future = Future.value(map);

      when(fixture.methodChannel.invokeMapMethod<String, dynamic>(
              'endNativeFrames', {'id': sentryId.toString()}))
          .thenAnswer((_) => future);

      final sut = fixture.getSut();
      final actual = await sut.endNativeFrames(sentryId);

      expect(actual?.totalFrames, 3);
      expect(actual?.slowFrames, 2);
      expect(actual?.frozenFrames, 1);
    });
  });
}

class Fixture {
  final methodChannel = MockMethodChannel();
  final options = SentryFlutterOptions();

  SentryNativeChannel getSut() {
    return SentryNativeChannel(methodChannel, options);
  }
}
