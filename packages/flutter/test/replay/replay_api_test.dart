// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../mocks.mocks.dart';

void main() {
  group('$SentryReplay', () {
    late MockSentryNativeBinding native;

    setUp(() {
      native = MockSentryNativeBinding();
      when(native.supportsReplay).thenReturn(true);
      when(native.startReplay()).thenReturn(null);
      when(native.startReplayBuffering()).thenReturn(null);
      when(native.pauseReplay()).thenReturn(null);
      when(native.resumeReplay()).thenReturn(null);
      when(native.stopReplay()).thenReturn(null);
      when(native.flushReplay()).thenReturn(null);
      SentryFlutter.native = native;
    });

    tearDown(() {
      SentryFlutter.native = null;
    });

    test('start forwards to the native binding', () async {
      await SentryFlutter.replay.start();

      verify(native.startReplay()).called(1);
    });

    test('startBuffering forwards to the native binding', () async {
      await SentryFlutter.replay.startBuffering();

      verify(native.startReplayBuffering()).called(1);
    });

    test('pause forwards to the native binding', () async {
      await SentryFlutter.replay.pause();

      verify(native.pauseReplay()).called(1);
    });

    test('resume forwards to the native binding', () async {
      await SentryFlutter.replay.resume();

      verify(native.resumeReplay()).called(1);
    });

    test('stop forwards to the native binding', () async {
      await SentryFlutter.replay.stop();

      verify(native.stopReplay()).called(1);
    });

    test('flush forwards to the native binding', () async {
      await SentryFlutter.replay.flush();

      verify(native.flushReplay()).called(1);
    });

    test('completes when native integration is unavailable', () async {
      SentryFlutter.native = null;

      await expectLater(SentryFlutter.replay.start(), completes);
    });

    test('does not invoke replay when the platform is unsupported', () async {
      when(native.supportsReplay).thenReturn(false);

      await SentryFlutter.replay.start();

      verifyNever(native.startReplay());
    });
  });
}
