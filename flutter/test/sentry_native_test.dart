import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/sentry_native.dart';
import 'package:sentry_flutter/src/sentry_native_channel.dart';
import 'mocks.dart';

void main() {
  group('$SentryNative', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    tearDown(() {
      fixture.getSut().reset();
    });

    test('fetchNativeAppStart sets didFetchAppStart', () async {
      final nativeAppStart = NativeAppStart(0.0, true);
      fixture.channel.nativeAppStart = nativeAppStart;

      final sut = fixture.getSut();

      expect(sut.didFetchAppStart, false);

      final firstCall = await sut.fetchNativeAppStart();
      expect(firstCall, nativeAppStart);

      expect(sut.didFetchAppStart, true);
    });

    test('beginNativeFramesCollection', () async {
      final sut = fixture.getSut();

      await sut.beginNativeFramesCollection();

      expect(fixture.channel.numberOfBeginNativeFramesCalls, 1);
    });

    test('endNativeFramesCollection', () async {
      final nativeFrames = NativeFrames(3, 2, 1);
      final traceId = SentryId.empty();
      fixture.channel.nativeFrames = nativeFrames;

      final sut = fixture.getSut();

      final actual = await sut.endNativeFramesCollection(traceId);

      expect(actual, nativeFrames);
      expect(fixture.channel.id, traceId);
      expect(fixture.channel.numberOfEndNativeFramesCalls, 1);
    });

    test('reset', () async {
      final sut = fixture.getSut();

      sut.appStartEnd = DateTime.now();
      await sut.fetchNativeAppStart();

      sut.reset();

      expect(sut.appStartEnd, null);
      expect(sut.didFetchAppStart, false);
    });
  });
}

class Fixture {
  final channel = MockNativeChannel();

  SentryNative getSut() {
    final sut = SentryNative();
    sut.setNativeChannel(channel);
    return sut;
  }
}
