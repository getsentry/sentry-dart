// ignore_for_file: inference_failure_on_function_invocation

@TestOn('vm')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/method_channel_helper.dart';
import 'package:sentry_flutter/src/native/sentry_native.dart';
import 'package:sentry_flutter/src/native/sentry_native_channel.dart';
import 'mocks.mocks.dart';

void main() {
  group('$SentryNative', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('fetchNativeAppStart', () async {
      final map = <String, dynamic>{
        'pluginRegistrationTime': 1,
        'appStartTime': 0.1,
        'isColdStart': true,
        // ignore: inference_failure_on_collection_literal
        'nativeSpanTimes': {},
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
      when(fixture.methodChannel.invokeMethod('beginNativeFrames'))
          .thenAnswer((realInvocation) async {});
      await sut.beginNativeFrames();

      verify(fixture.methodChannel.invokeMethod('beginNativeFrames'));
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

    test('setUser', () async {
      final user = SentryUser(
        id: "fixture-id",
        data: {'object': Object()},
      );
      final normalizedUser = user.copyWith(
        data: MethodChannelHelper.normalizeMap(user.data),
      );
      when(fixture.methodChannel
              .invokeMethod('setUser', {'user': normalizedUser.toJson()}))
          .thenAnswer((_) => Future.value());

      final sut = fixture.getSut();
      await sut.setUser(user);

      verify(fixture.methodChannel
          .invokeMethod('setUser', {'user': normalizedUser.toJson()}));
    });

    test('addBreadcrumb', () async {
      final breadcrumb = Breadcrumb(
        data: {'object': Object()},
      );
      final normalizedBreadcrumb = breadcrumb.copyWith(
          data: MethodChannelHelper.normalizeMap(breadcrumb.data));

      when(fixture.methodChannel.invokeMethod(
              'addBreadcrumb', {'breadcrumb': normalizedBreadcrumb.toJson()}))
          .thenAnswer((_) => Future.value());

      final sut = fixture.getSut();
      await sut.addBreadcrumb(breadcrumb);

      verify(fixture.methodChannel.invokeMethod(
          'addBreadcrumb', {'breadcrumb': normalizedBreadcrumb.toJson()}));
    });

    test('clearBreadcrumbs', () async {
      when(fixture.methodChannel.invokeMethod('clearBreadcrumbs'))
          .thenAnswer((_) => Future.value());

      final sut = fixture.getSut();
      await sut.clearBreadcrumbs();

      verify(fixture.methodChannel.invokeMethod('clearBreadcrumbs'));
    });

    test('setContexts', () async {
      final value = {'object': Object()};
      final normalizedValue = MethodChannelHelper.normalize(value);
      when(fixture.methodChannel.invokeMethod(
              'setContexts', {'key': 'fixture-key', 'value': normalizedValue}))
          .thenAnswer((_) => Future.value());

      final sut = fixture.getSut();
      await sut.setContexts('fixture-key', value);

      verify(fixture.methodChannel.invokeMethod(
          'setContexts', {'key': 'fixture-key', 'value': normalizedValue}));
    });

    test('removeContexts', () async {
      when(fixture.methodChannel
              .invokeMethod('removeContexts', {'key': 'fixture-key'}))
          .thenAnswer((_) => Future.value());

      final sut = fixture.getSut();
      await sut.removeContexts('fixture-key');

      verify(fixture.methodChannel
          .invokeMethod('removeContexts', {'key': 'fixture-key'}));
    });

    test('setExtra', () async {
      final value = {'object': Object()};
      final normalizedValue = MethodChannelHelper.normalize(value);
      when(fixture.methodChannel.invokeMethod(
              'setExtra', {'key': 'fixture-key', 'value': normalizedValue}))
          .thenAnswer((_) => Future.value());

      final sut = fixture.getSut();
      await sut.setExtra('fixture-key', value);

      verify(fixture.methodChannel.invokeMethod(
          'setExtra', {'key': 'fixture-key', 'value': normalizedValue}));
    });

    test('removeExtra', () async {
      when(fixture.methodChannel
              .invokeMethod('removeExtra', {'key': 'fixture-key'}))
          .thenAnswer((_) => Future.value());

      final sut = fixture.getSut();
      await sut.removeExtra('fixture-key');

      verify(fixture.methodChannel
          .invokeMethod('removeExtra', {'key': 'fixture-key'}));
    });

    test('setTag', () async {
      when(fixture.methodChannel.invokeMethod(
              'setTag', {'key': 'fixture-key', 'value': 'fixture-value'}))
          .thenAnswer((_) => Future.value());

      final sut = fixture.getSut();
      await sut.setTag('fixture-key', 'fixture-value');

      verify(fixture.methodChannel.invokeMethod(
          'setTag', {'key': 'fixture-key', 'value': 'fixture-value'}));
    });

    test('removeTag', () async {
      when(fixture.methodChannel
              .invokeMethod('removeTag', {'key': 'fixture-key'}))
          .thenAnswer((_) => Future.value());

      final sut = fixture.getSut();
      await sut.removeTag('fixture-key');

      verify(fixture.methodChannel
          .invokeMethod('removeTag', {'key': 'fixture-key'}));
    });

    test('startProfiler', () {
      final sut = fixture.getSut();
      expect(() => sut.startProfiler(SentryId.newId()), throwsUnsupportedError);
      verifyZeroInteractions(fixture.methodChannel);
    });

    test('discardProfiler', () async {
      final traceId = SentryId.newId();
      when(fixture.methodChannel
              .invokeMethod('discardProfiler', traceId.toString()))
          .thenAnswer((_) async {});

      final sut = fixture.getSut();
      await sut.discardProfiler(traceId);

      verify(fixture.methodChannel
          .invokeMethod('discardProfiler', traceId.toString()));
    });

    test('collectProfile', () async {
      final traceId = SentryId.newId();
      const startTime = 42;
      const endTime = 50;
      when(fixture.methodChannel
          .invokeMapMethod<String, dynamic>('collectProfile', {
        'traceId': traceId.toString(),
        'startTime': startTime,
        'endTime': endTime,
      })).thenAnswer((_) => Future.value());

      final sut = fixture.getSut();
      await sut.collectProfile(traceId, startTime, endTime);

      verify(fixture.methodChannel.invokeMapMethod('collectProfile', {
        'traceId': traceId.toString(),
        'startTime': startTime,
        'endTime': endTime,
      }));
    });
  });
}

class Fixture {
  final methodChannel = MockMethodChannel();

  SentryNativeChannel getSut() {
    return SentryNativeChannel(methodChannel);
  }
}
