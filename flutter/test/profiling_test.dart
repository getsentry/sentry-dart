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
      SentryNativeProfilerFactory.attachTo(hub, TestMockSentryNative());
      // ignore: invalid_use_of_internal_member
      verifyNever(hub.profilerFactory = any);

      hub = hubWithSampleRate(0.1);
      SentryNativeProfilerFactory.attachTo(hub, TestMockSentryNative());
      // ignore: invalid_use_of_internal_member
      verify(hub.profilerFactory = any);
    });

    test('creates a profiler', () async {
      final nativeMock = TestMockSentryNative();
      // ignore: invalid_use_of_internal_member
      final sut = SentryNativeProfilerFactory(nativeMock, getUtcDateTime);
      final profiler = sut.startProfiler(SentryTransactionContext(
        'name',
        'op',
      ));
      expect(nativeMock.numberOfStartProfilerCalls, 1);
      expect(profiler, isNotNull);
    });
  });

  group('$SentryNativeProfiler', () {
    late TestMockSentryNative nativeMock;
    late SentryNativeProfiler sut;

    setUp(() {
      nativeMock = TestMockSentryNative();
      // ignore: invalid_use_of_internal_member
      final factory = SentryNativeProfilerFactory(nativeMock, getUtcDateTime);
      final profiler = factory.startProfiler(SentryTransactionContext(
        'name',
        'op',
      ));
      expect(nativeMock.numberOfStartProfilerCalls, 1);
      expect(profiler, isNotNull);
      sut = profiler!;
    });

    test('dispose() calls native discard() exactly once', () async {
      sut.dispose();
      sut.dispose(); // Additional calls must not have an effect.

      // Yield to let the .then() in .dispose() execute.
      await null;
      await null;

      expect(nativeMock.numberOfDiscardProfilerCalls, 1);

      // finishFor() mustn't work after disposing
      expect(await sut.finishFor(MockSentryTransaction()), isNull);
      expect(nativeMock.numberOfCollectProfileCalls, 0);
    });

    test('dispose() does not call discard() after finishing', () async {
      final mockTransaction = MockSentryTransaction();
      when(mockTransaction.startTimestamp).thenReturn(DateTime.now());
      when(mockTransaction.timestamp).thenReturn(DateTime.now());
      expect(await sut.finishFor(mockTransaction), isNull);

      sut.dispose();

      // Yield to let the .then() in .dispose() execute.
      await null;

      expect(nativeMock.numberOfDiscardProfilerCalls, 0);
      expect(nativeMock.numberOfCollectProfileCalls, 1);
    });
  });
}
