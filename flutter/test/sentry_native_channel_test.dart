// ignore_for_file: inference_failure_on_function_invocation

@TestOn('vm')
library flutter_test;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/factory.dart';
import 'package:sentry_flutter/src/native/method_channel_helper.dart';
import 'package:sentry_flutter/src/native/sentry_native_binding.dart';
import 'package:sentry/src/platform/platform.dart' as platform;
import 'mocks.dart';
import 'mocks.mocks.dart';
import 'sentry_flutter_test.dart';

void main() {
  for (var mockPlatform in [
    MockPlatform.android(),
    MockPlatform.iOs(),
    MockPlatform.macOs()
  ]) {
    group('$SentryNativeBinding', () {
      late SentryNativeBinding sut;
      late MockMethodChannel channel;

      setUp(() {
        final options = SentryFlutterOptions(
            dsn: fakeDsn, checker: getPlatformChecker(platform: mockPlatform))
          // ignore: invalid_use_of_internal_member
          ..automatedTestMode = true;
        channel = MockMethodChannel();
        sut = createBinding(options, channel: channel);
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

      test('beginNativeFrames', () async {
        when(channel.invokeMethod('beginNativeFrames'))
            .thenAnswer((realInvocation) async {});
        await sut.beginNativeFrames();

        verify(channel.invokeMethod('beginNativeFrames'));
      });

      test('endNativeFrames', () async {
        final sentryId = SentryId.empty();

        when(channel
                .invokeMethod('endNativeFrames', {'id': sentryId.toString()}))
            .thenAnswer((_) async => {
                  'totalFrames': 3,
                  'slowFrames': 2,
                  'frozenFrames': 1,
                });

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
        final normalizedBreadcrumb = breadcrumb.copyWith(
            data: MethodChannelHelper.normalizeMap(breadcrumb.data));

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
          if (platform.instance.isMacOS) {
            matcher = throwsA(predicate((e) =>
                e is Exception &&
                e.toString().contains('Failed to load Objective-C class')));
          } else {
            matcher = throwsA(predicate((e) =>
                e is ArgumentError &&
                e.toString().contains('Failed to lookup symbol')));
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

      test('captureEnvelope', () async {
        final data = Uint8List.fromList([1, 2, 3]);

        late Uint8List captured;
        when(channel.invokeMethod('captureEnvelope', any)).thenAnswer(
            (invocation) async =>
                {captured = invocation.positionalArguments[1][0] as Uint8List});

        await sut.captureEnvelope(data, false);

        expect(captured, data);
      });

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

        when(channel.invokeMethod('loadImageList'))
            .thenAnswer((invocation) async => json);

        final data = await sut.loadDebugImages();

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
    });
  }
}
