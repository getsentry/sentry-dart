// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../mocks.mocks.dart';

void main() {
  group('$SentryReplay', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    tearDown(() {
      SentryFlutter.native = null;
    });

    test('start forwards to the native binding', () async {
      await fixture.getSut().start();

      verify(fixture.native.startReplay()).called(1);
    });

    test('startBuffering forwards to the native binding', () async {
      await fixture.getSut().startBuffering();

      verify(fixture.native.startReplayBuffering()).called(1);
    });

    test('pause forwards to the native binding', () async {
      await fixture.getSut().pause();

      verify(fixture.native.pauseReplay()).called(1);
    });

    test('resume forwards to the native binding', () async {
      await fixture.getSut().resume();

      verify(fixture.native.resumeReplay()).called(1);
    });

    test('stop forwards to the native binding', () async {
      await fixture.getSut().stop();

      verify(fixture.native.stopReplay()).called(1);
    });

    test('flush forwards to the native binding', () async {
      await fixture.getSut().flush();

      verify(fixture.native.flushReplay()).called(1);
    });

    test('waits for an asynchronous native call', () async {
      final nativeCall = Completer<void>();
      when(fixture.native.startReplay()).thenAnswer((_) => nativeCall.future);
      var completed = false;

      final start = fixture.getSut().start().then((_) => completed = true);
      await Future<void>.value();

      expect(completed, false);

      nativeCall.complete();
      await start;

      expect(completed, true);
    });

    test('completes when native integration is unavailable', () async {
      SentryFlutter.native = null;

      await expectLater(fixture.getSut().start(), completes);
    });

    test('does not invoke replay when the platform is unsupported', () async {
      when(fixture.native.supportsReplay).thenReturn(false);

      await fixture.getSut().start();

      verifyNever(fixture.native.startReplay());
    });
  });
}

class Fixture {
  final native = MockSentryNativeBinding();

  Fixture() {
    when(native.supportsReplay).thenReturn(true);
    when(native.startReplay()).thenReturn(null);
    when(native.startReplayBuffering()).thenReturn(null);
    when(native.pauseReplay()).thenReturn(null);
    when(native.resumeReplay()).thenReturn(null);
    when(native.stopReplay()).thenReturn(null);
    when(native.flushReplay()).thenReturn(null);
    SentryFlutter.native = native;
  }

  SentryReplay getSut() => SentryFlutter.replay;
}
