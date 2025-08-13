// ignore_for_file: inference_failure_on_function_invocation

@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/src/platform/mock_platform.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/factory.dart';
import 'package:sentry_flutter/src/native/method_channel_helper.dart';
import 'package:sentry_flutter/src/native/sentry_native_binding.dart';
import 'package:sentry_flutter/src/replay/replay_config.dart';

import 'mocks.dart';
import 'mocks.mocks.dart';

void main() {
  for (var mockPlatform in [
    MockPlatform.android(),
    MockPlatform.iOS(),
    MockPlatform.macOS()
  ]) {
    group('$SentryNativeBinding', () {
      late SentryNativeBinding sut;
      late MockMethodChannel channel;

      setUp(() {
        channel = MockMethodChannel();
        final options = defaultTestOptions()
          ..platform = mockPlatform
          ..methodChannel = channel;
        sut = createBinding(options);
      });

      // TODO move other methods here, e.g. init_native_sdk_test.dart

      test('fetchNativeAppStart', () async {
        when(channel.invokeMethod('fetchNativeAppStart'))
            .thenAnswer((_) async => {
                  'pluginRegistrationTime': 1,
                  'appStartTime': 0.1,
                  'isColdStart': true,
                  // ignore: inference_failure_on_collection_literal
                  'nativeSpanTimes': {},
                });

        final actual = await sut.fetchNativeAppStart();

        expect(actual?.appStartTime, 0.1);
        expect(actual?.isColdStart, true);
      });

      test('invalid fetchNativeAppStart returns null', () async {
        when(channel.invokeMethod('fetchNativeAppStart'))
            .thenAnswer((_) async => {
                  'pluginRegistrationTime': 'invalid',
                  'appStartTime': 'invalid',
                  'isColdStart': 'invalid',
                  // ignore: inference_failure_on_collection_literal
                  'nativeSpanTimes': 'invalid',
                });

        final actual = await sut.fetchNativeAppStart();

        expect(actual, isNull);
      });

      test('setUser', () async {
        final user = SentryUser(
          id: "fixture-id",
          data: {'object': Object()},
        );
        final normalizedUser = SentryUser(
          id: user.id,
          username: user.username,
          email: user.email,
          ipAddress: user.ipAddress,
          data: MethodChannelHelper.normalizeMap(user.data),
          // ignore: deprecated_member_use
          extras: user.extras,
          geo: user.geo,
          name: user.name,
          // ignore: invalid_use_of_internal_member
          unknown: user.unknown,
        );
        when(channel.invokeMethod('setUser', {'user': normalizedUser.toJson()}))
            .thenAnswer((_) => Future.value());

        await sut.setUser(user);

        verify(
            channel.invokeMethod('setUser', {'user': normalizedUser.toJson()}));
      });

      test('addBreadcrumb', () async {
        final breadcrumb = Breadcrumb(
          data: {'object': Object()},
        );
        final normalizedBreadcrumb = Breadcrumb(
          message: breadcrumb.message,
          category: breadcrumb.category,
          data: MethodChannelHelper.normalizeMap(breadcrumb.data),
          level: breadcrumb.level,
          type: breadcrumb.type,
          timestamp: breadcrumb.timestamp,
          // ignore: invalid_use_of_internal_member
          unknown: breadcrumb.unknown,
        );
        when(channel.invokeMethod(
                'addBreadcrumb', {'breadcrumb': normalizedBreadcrumb.toJson()}))
            .thenAnswer((_) => Future.value());

        await sut.addBreadcrumb(breadcrumb);

        verify(channel.invokeMethod(
            'addBreadcrumb', {'breadcrumb': normalizedBreadcrumb.toJson()}));
      });

      test('clearBreadcrumbs', () async {
        when(channel.invokeMethod('clearBreadcrumbs'))
            .thenAnswer((_) => Future.value());

        await sut.clearBreadcrumbs();

        verify(channel.invokeMethod('clearBreadcrumbs'));
      });

      test('setContexts', () async {
        final value = {'object': Object()};
        final normalizedValue = MethodChannelHelper.normalize(value);
        when(channel.invokeMethod('setContexts', {
          'key': 'fixture-key',
          'value': normalizedValue
        })).thenAnswer((_) => Future.value());

        await sut.setContexts('fixture-key', value);

        verify(channel.invokeMethod(
            'setContexts', {'key': 'fixture-key', 'value': normalizedValue}));
      });

      test('removeContexts', () async {
        when(channel.invokeMethod('removeContexts', {'key': 'fixture-key'}))
            .thenAnswer((_) => Future.value());

        await sut.removeContexts('fixture-key');

        verify(channel.invokeMethod('removeContexts', {'key': 'fixture-key'}));
      });

      test('setExtra', () async {
        final value = {'object': Object()};
        final normalizedValue = MethodChannelHelper.normalize(value);
        when(channel.invokeMethod(
                'setExtra', {'key': 'fixture-key', 'value': normalizedValue}))
            .thenAnswer((_) => Future.value());

        await sut.setExtra('fixture-key', value);

        verify(channel.invokeMethod(
            'setExtra', {'key': 'fixture-key', 'value': normalizedValue}));
      });

      test('removeExtra', () async {
        when(channel.invokeMethod('removeExtra', {'key': 'fixture-key'}))
            .thenAnswer((_) => Future.value());

        await sut.removeExtra('fixture-key');

        verify(channel.invokeMethod('removeExtra', {'key': 'fixture-key'}));
      });

      test('setTag', () async {
        when(channel.invokeMethod(
                'setTag', {'key': 'fixture-key', 'value': 'fixture-value'}))
            .thenAnswer((_) => Future.value());

        await sut.setTag('fixture-key', 'fixture-value');

        verify(channel.invokeMethod(
            'setTag', {'key': 'fixture-key', 'value': 'fixture-value'}));
      });

      test('removeTag', () async {
        when(channel.invokeMethod('removeTag', {'key': 'fixture-key'}))
            .thenAnswer((_) => Future.value());

        await sut.removeTag('fixture-key');

        verify(channel.invokeMethod('removeTag', {'key': 'fixture-key'}));
      });

      test('startProfiler', () {
        late Matcher matcher;
        if (mockPlatform.isAndroid) {
          matcher = throwsUnsupportedError;
        } else if (mockPlatform.isIOS || mockPlatform.isMacOS) {
          if (mockPlatform.isMacOS) {
            matcher = throwsA(predicate((e) =>
                (e is Exception &&
                    e
                        .toString()
                        .contains('Failed to load Objective-C class')) ||
                (e is ArgumentError &&
                    e
                        .toString()
                        .contains('Couldn\'t resolve native function'))));
          } else {
            matcher = throwsA(predicate((e) =>
                (e is ArgumentError &&
                    (e.toString().contains('undefined symbol: objc_msgSend') ||
                        e
                            .toString()
                            .contains('Couldn\'t resolve native function'))) ||
                (e is Exception &&
                    e
                        .toString()
                        .contains('Failed to load Objective-C class'))));
          }
        }
        expect(() => sut.startProfiler(SentryId.newId()), matcher);

        verifyZeroInteractions(channel);
      });

      test('discardProfiler', () async {
        final traceId = SentryId.newId();
        when(channel.invokeMethod('discardProfiler', traceId.toString()))
            .thenAnswer((_) async {});

        await sut.discardProfiler(traceId);

        verify(channel.invokeMethod('discardProfiler', traceId.toString()));
      });

      test('collectProfile', () async {
        final traceId = SentryId.newId();
        const startTime = 42;
        const endTime = 50;
        when(channel.invokeMethod('collectProfile', {
          'traceId': traceId.toString(),
          'startTime': startTime,
          'endTime': endTime,
        })).thenAnswer((_) async => {});

        await sut.collectProfile(traceId, startTime, endTime);

        verify(channel.invokeMethod('collectProfile', {
          'traceId': traceId.toString(),
          'startTime': startTime,
          'endTime': endTime,
        }));
      });

      test(
        'captureEnvelope',
        () {
          when(channel.invokeMethod('captureEnvelope', any))
              .thenAnswer((_) async => {});

          late Matcher matcher;
          if (mockPlatform.isAndroid) {
            matcher = throwsA(predicate((e) =>
                e is Error &&
                e.toString().contains('Unable to locate the helper library')));
          } else if (mockPlatform.isIOS || mockPlatform.isMacOS) {
            if (mockPlatform.isMacOS) {
              matcher = throwsA(predicate((e) =>
                  (e is Exception &&
                      (e
                          .toString()
                          .contains('Failed to load Objective-C class'))) ||
                  (e is ArgumentError &&
                      e
                          .toString()
                          .contains('Couldn\'t resolve native function'))));
            } else {
              matcher = throwsA(predicate((e) =>
                  e is ArgumentError &&
                  (e.toString().contains('undefined symbol: objc_msgSend') ||
                      e
                          .toString()
                          .contains('Couldn\'t resolve native function') ||
                      e.toString().contains('Failed to lookup symbol'))));
            }
          }

          final data = Uint8List.fromList([1, 2, 3]);
          expect(() => sut.captureEnvelope(data, false), matcher);

          verifyZeroInteractions(channel);
        },
      );

      test('loadContexts', () async {
        when(channel.invokeMethod('loadContexts'))
            .thenAnswer((invocation) async => {
                  'foo': [1, 2, 3],
                  'bar': {'a': 'b'},
                });

        final data = await sut.loadContexts();

        expect(data, {
          'foo': [1, 2, 3],
          'bar': {'a': 'b'},
        });
      });

      test('loadDebugImages', () async {
        final json = [
          {
            'code_file': '/apex/com.android.art/javalib/arm64/boot.oat',
            'code_id': '13577ce71153c228ecf0eb73fc39f45010d487f8',
            'image_addr': '0x6f80b000',
            'image_size': 3092480,
            'type': 'elf',
            'debug_id': 'e77c5713-5311-28c2-ecf0-eb73fc39f450',
            'debug_file': 'test'
          }
        ];

        when(channel.invokeMethod('loadImageList', any))
            .thenAnswer((invocation) async => json);

        final data = await sut.loadDebugImages(SentryStackTrace(frames: []));

        expect(data?.map((v) => v.toJson()), json);
      });

      test('pauseAppHangTracking', () async {
        when(channel.invokeMethod('pauseAppHangTracking'))
            .thenAnswer((_) => Future.value());

        await sut.pauseAppHangTracking();

        verify(channel.invokeMethod('pauseAppHangTracking'));
      });

      test('resumeAppHangTracking', () async {
        when(channel.invokeMethod('resumeAppHangTracking'))
            .thenAnswer((_) => Future.value());

        await sut.resumeAppHangTracking();

        verify(channel.invokeMethod('resumeAppHangTracking'));
      });

      test('nativeCrash', () async {
        when(channel.invokeMethod('nativeCrash'))
            .thenAnswer((_) => Future.value());

        await sut.nativeCrash();

        verify(channel.invokeMethod('nativeCrash'));
      });

      test('setReplayConfig', () async {
        when(channel.invokeMethod('setReplayConfig', any))
            .thenAnswer((_) => Future.value());

        final config = ReplayConfig(
            windowWidth: 110,
            windowHeight: 220,
            width: 1.1,
            height: 2.2,
            frameRate: 3);
        await sut.setReplayConfig(config);

        if (mockPlatform.isAndroid) {
          verify(channel.invokeMethod('setReplayConfig', {
            'windowWidth': config.windowWidth,
            'windowHeight': config.windowHeight,
            'width': config.width,
            'height': config.height,
            'frameRate': config.frameRate,
          }));
        } else {
          verifyNever(channel.invokeMethod('setReplayConfig', any));
        }
      });

      test('captureReplay', () async {
        final sentryId = SentryId.newId();

        when(channel.invokeMethod('captureReplay', any))
            .thenAnswer((_) => Future.value(sentryId.toString()));

        final returnedId = await sut.captureReplay();

        verify(channel.invokeMethod('captureReplay'));
        expect(returnedId, sentryId);
      });

      test('getSession is no-op', () async {
        await sut.getSession();

        verifyZeroInteractions(channel);
      });

      test('updateSession is no-op', () async {
        await sut.updateSession(status: 'test', errors: 1);

        verifyZeroInteractions(channel);
      });

      test('captureSession is no-op', () async {
        await sut.captureSession();

        verifyZeroInteractions(channel);
      });
    });
  }
}
