@TestOn('vm')

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/sentry_native.dart';
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

    test('setUser', () async {
      final sut = fixture.getSut();
      await sut.setUser(null);

      expect(fixture.channel.numberOfSetUserCalls, 1);
    });

    test('addBreadcrumb', () async {
      final sut = fixture.getSut();
      await sut.addBreadcrumb(Breadcrumb());

      expect(fixture.channel.numberOfAddBreadcrumbCalls, 1);
    });

    test('clearBreadcrumbs', () async {
      final sut = fixture.getSut();
      await sut.clearBreadcrumbs();

      expect(fixture.channel.numberOfClearBreadcrumbCalls, 1);
    });

    test('setContexts', () async {
      final sut = fixture.getSut();
      await sut.setContexts('fixture-key', 'fixture-value');

      expect(fixture.channel.numberOfSetContextsCalls, 1);
    });

    test('removeContexts', () async {
      final sut = fixture.getSut();
      await sut.removeContexts('fixture-key');

      expect(fixture.channel.numberOfRemoveContextsCalls, 1);
    });

    test('setExtra', () async {
      final sut = fixture.getSut();
      await sut.setExtra('fixture-key', 'fixture-value');

      expect(fixture.channel.numberOfSetExtraCalls, 1);
    });

    test('removeExtra', () async {
      final sut = fixture.getSut();
      await sut.removeExtra('fixture-key');

      expect(fixture.channel.numberOfRemoveExtraCalls, 1);
    });

    test('setTag', () async {
      final sut = fixture.getSut();
      await sut.setTag('fixture-key', 'fixture-value');

      expect(fixture.channel.numberOfSetTagCalls, 1);
    });

    test('removeTag', () async {
      final sut = fixture.getSut();
      await sut.removeTag('fixture-key');

      expect(fixture.channel.numberOfRemoveTagCalls, 1);
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
    sut.nativeChannel = channel;
    return sut;
  }
}
