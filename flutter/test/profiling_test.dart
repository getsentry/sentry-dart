@TestOn('vm')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/profiling.dart';
import 'mocks.dart';
import 'mocks.mocks.dart';
import 'sentry_flutter_test.dart';

void main() {
  late MockSentryNativeBinding mock;

  setUp(() {
    mock = MockSentryNativeBinding();
    when(mock.startProfiler(any)).thenReturn(1);
  });

  group('$SentryNativeProfilerFactory', () {
    Hub hubWithSampleRate(double profilesSampleRate) {
      final o = SentryFlutterOptions(dsn: fakeDsn);
      o.platformChecker = getPlatformChecker(platform: MockPlatform.iOs());
      o.profilesSampleRate = profilesSampleRate;

      final hub = MockHub();
      when(hub.options).thenAnswer((_) => o);
      return hub;
    }

    test('attachTo() respects sampling rate', () async {
      var hub = hubWithSampleRate(0.0);
      SentryNativeProfilerFactory.attachTo(hub, mock);
      // ignore: invalid_use_of_internal_member
      verifyNever(hub.profilerFactory = any);

      hub = hubWithSampleRate(0.1);
      SentryNativeProfilerFactory.attachTo(hub, mock);
      // ignore: invalid_use_of_internal_member
      verify(hub.profilerFactory = any);
    });

    test('creates a profiler', () async {
      // ignore: invalid_use_of_internal_member
      final sut = SentryNativeProfilerFactory(mock, getUtcDateTime);
      final profiler = sut.startProfiler(SentryTransactionContext(
        'name',
        'op',
      ));
      verify(mock.startProfiler(any)).called(1);
      expect(profiler, isNotNull);
    });
  });

  group('$SentryNativeProfiler', () {
    late SentryNativeProfiler sut;

    setUp(() {
      // ignore: invalid_use_of_internal_member
      final factory = SentryNativeProfilerFactory(mock, getUtcDateTime);
      final profiler = factory.startProfiler(SentryTransactionContext(
        'name',
        'op',
      ));
      verify(mock.startProfiler(any)).called(1);
      expect(profiler, isNotNull);
      sut = profiler!;
    });

    test('dispose() calls native discard() exactly once', () async {
      sut.dispose();
      sut.dispose(); // Additional calls must not have an effect.

      // Yield to let the .then() in .dispose() execute.
      await null;
      await null;

      verify(mock.discardProfiler(any)).called(1);

      // finishFor() mustn't work after disposing
      expect(await sut.finishFor(MockSentryTransaction()), isNull);
      verifyNever(mock.collectProfile(any, any, any));
    });

    test('dispose() does not call discard() after finishing', () async {
      when(mock.collectProfile(any, any, any)).thenAnswer((_) async => null);
      final mockTransaction = MockSentryTransaction();
      when(mockTransaction.startTimestamp).thenReturn(DateTime.now());
      when(mockTransaction.timestamp).thenReturn(DateTime.now());
      expect(await sut.finishFor(mockTransaction), isNull);

      sut.dispose();

      // Yield to let the .then() in .dispose() execute.
      await null;

      verifyNever(mock.discardProfiler(any));
      verify(mock.collectProfile(any, any, any)).called(1);
    });
  });
}
