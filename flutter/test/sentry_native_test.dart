@TestOn('vm')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/sentry_native.dart';
import 'mocks.dart';

void main() {
  group('$SentryNative', () {
    final channel = MockNativeChannel();
    final options = SentryFlutterOptions(dsn: fakeDsn);
    late final sut = SentryNative(options, channel);

    tearDown(() {
      sut.reset();
    });

    test('fetchNativeAppStart sets didFetchAppStart', () async {
      final nativeAppStart = NativeAppStart(
          appStartTime: 0.0,
          pluginRegistrationTime: 10,
          isColdStart: true,
          nativeSpanTimes: {});
      channel.nativeAppStart = nativeAppStart;

      expect(sut.didFetchAppStart, false);

      final firstCall = await sut.fetchNativeAppStart();
      expect(firstCall, nativeAppStart);

      expect(sut.didFetchAppStart, true);
    });

    test('beginNativeFramesCollection', () async {
      await sut.beginNativeFramesCollection();
      expect(channel.numberOfBeginNativeFramesCalls, 1);
    });

    test('endNativeFramesCollection', () async {
      final nativeFrames = NativeFrames(3, 2, 1);
      final traceId = SentryId.empty();
      channel.nativeFrames = nativeFrames;

      final actual = await sut.endNativeFramesCollection(traceId);

      expect(actual, nativeFrames);
      expect(channel.id, traceId);
      expect(channel.numberOfEndNativeFramesCalls, 1);
    });

    test('setUser', () async {
      await sut.setUser(null);
      expect(channel.numberOfSetUserCalls, 1);
    });

    test('addBreadcrumb', () async {
      await sut.addBreadcrumb(Breadcrumb());
      expect(channel.numberOfAddBreadcrumbCalls, 1);
    });

    test('clearBreadcrumbs', () async {
      await sut.clearBreadcrumbs();
      expect(channel.numberOfClearBreadcrumbCalls, 1);
    });

    test('setContexts', () async {
      await sut.setContexts('fixture-key', 'fixture-value');
      expect(channel.numberOfSetContextsCalls, 1);
    });

    test('removeContexts', () async {
      await sut.removeContexts('fixture-key');
      expect(channel.numberOfRemoveContextsCalls, 1);
    });

    test('setExtra', () async {
      await sut.setExtra('fixture-key', 'fixture-value');
      expect(channel.numberOfSetExtraCalls, 1);
    });

    test('removeExtra', () async {
      await sut.removeExtra('fixture-key');
      expect(channel.numberOfRemoveExtraCalls, 1);
    });

    test('setTag', () async {
      await sut.setTag('fixture-key', 'fixture-value');
      expect(channel.numberOfSetTagCalls, 1);
    });

    test('removeTag', () async {
      await sut.removeTag('fixture-key');
      expect(channel.numberOfRemoveTagCalls, 1);
    });

    test('startProfiler', () async {
      sut.startProfiler(SentryId.newId());
      expect(channel.numberOfStartProfilerCalls, 1);
    });

    test('discardProfiler', () async {
      await sut.discardProfiler(SentryId.newId());
      expect(channel.numberOfDiscardProfilerCalls, 1);
    });

    test('collectProfile', () async {
      await sut.collectProfile(SentryId.newId(), 1, 2);
      expect(channel.numberOfCollectProfileCalls, 1);
    });

    test('reset', () async {
      sut.appStartEnd = DateTime.now();
      await sut.fetchNativeAppStart();
      sut.reset();
      expect(sut.appStartEnd, null);
      expect(sut.didFetchAppStart, false);
    });
  });
}
