@TestOn('vm')

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/profiling.dart';
import 'package:sentry_flutter/src/sentry_native.dart';
import 'package:sentry_flutter/src/sentry_native_channel.dart';
import 'mocks.dart';
import 'mocks.mocks.dart';
import 'sentry_flutter_test.dart';

void main() {
  group('$NativeProfilerFactory', () {
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
      NativeProfilerFactory.attachTo(hub);
      verifyNever(hub.profilerFactory = any);

      hub = hubWithSampleRate(0.1);
      NativeProfilerFactory.attachTo(hub);
      verify(hub.profilerFactory = any);
    });

    test('creates a profiler', () async {
      final nativeMock = TestMockSentryNative();
      final sut = NativeProfilerFactory(nativeMock);
      final profiler = sut.startProfiling(SentryTransactionContext(
        'name',
        'op',
      ));
      expect(nativeMock.numberOfStartProfilingCalls, 1);
      expect(profiler, isNotNull);
    });
  });
}
