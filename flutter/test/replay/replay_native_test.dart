// ignore_for_file: invalid_use_of_internal_member

@TestOn('vm')
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/src/platform/mock_platform.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/factory.dart';
import 'android_replay_recorder_web.dart' // see https://github.com/flutter/flutter/issues/160675
    if (dart.library.io) 'package:sentry_flutter/src/native/java/android_replay_recorder.dart';
import 'package:sentry_flutter/src/replay/scheduled_recorder.dart';
import 'package:sentry_flutter/src/screenshot/screenshot.dart';
import '../native_memory_web_mock.dart'
    if (dart.library.io) 'package:sentry_flutter/src/native/native_memory.dart';
import 'package:sentry_flutter/src/native/sentry_native_binding.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';
import '../screenshot/test_widget.dart';
import 'replay_test_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final mockPlatform in [
    MockPlatform.android(),
    MockPlatform.iOS(),
  ]) {
    group('$SentryNativeBinding (${mockPlatform.operatingSystem})', () {
      late SentryNativeBinding sut;
      late NativeChannelFixture native;
      late SentryFlutterOptions options;
      late MockHub hub;
      late Map<String, dynamic> replayConfig;
      late _MockAndroidReplayRecorder mockAndroidRecorder;

      setUp(() {
        hub = MockHub();
        native = NativeChannelFixture();

        options = defaultTestOptions()
          ..platform = mockPlatform
          ..methodChannel = native.channel
          ..replay.quality = SentryReplayQuality.low;

        sut = createBinding(options);

        if (mockPlatform.isIOS) {
          replayConfig = {
            'replayId': '123',
          };
        } else if (mockPlatform.isAndroid) {
          replayConfig = {
            'replayId': '123',
            'width': 800,
            'height': 600,
            'frameRate': 1000,
          };
          AndroidReplayRecorder.factory = (config, options) {
            mockAndroidRecorder = _MockAndroidReplayRecorder(config, options);
            return mockAndroidRecorder;
          };
        }
      });

      tearDown(() async {
        await sut.close();
      });

      group('replay recorder', () {
        setUp(() async {
          options.replay.sessionSampleRate = 0.1;
          options.replay.onErrorSampleRate = 0.1;
          await sut.init(hub);
        });

        testWidgets('sets replayID to context', (tester) async {
          await tester.runAsync(() async {
            await pumpTestElement(tester);
            // verify there was no scope configured before
            verifyNever(hub.configureScope(any));
            when(hub.configureScope(captureAny)).thenReturn(null);

            // emulate the native platform invoking the method
            final future = native.invokeFromNative(
                mockPlatform.isAndroid
                    ? 'ReplayRecorder.start'
                    : 'captureReplayScreenshot',
                replayConfig);
            tester.binding.scheduleFrame();
            await tester.pumpAndWaitUntil(future);

            // verify the replay ID was set
            final closure =
                verify(hub.configureScope(captureAny)).captured.single;
            final scope = Scope(options);
            expect(scope.replayId, isNull);
            await closure(scope);
            expect(scope.replayId.toString(), replayConfig['replayId']);

            if (mockPlatform.isAndroid) {
              await native.invokeFromNative('ReplayRecorder.stop');
              AndroidReplayRecorder.factory = AndroidReplayRecorder.new;

              // Workaround for "A Timer is still pending even after the widget tree was disposed."
              await tester.pumpWidget(Container());
              await tester.pumpAndSettle();
            }
          });
        });

        test('clears replay ID from context', () async {
          // verify there was no scope configured before
          verifyNever(hub.configureScope(any));
          when(hub.configureScope(captureAny)).thenReturn(null);

          // emulate the native platform invoking the method
          await native.invokeFromNative('ReplayRecorder.stop');

          // verify the replay ID was cleared
          final closure =
              verify(hub.configureScope(captureAny)).captured.single;
          final scope = Scope(options);
          scope.replayId = SentryId.newId();
          expect(scope.replayId, isNotNull);
          await closure(scope);
          expect(scope.replayId, isNull);
        }, skip: mockPlatform.isIOS ? 'iOS does not clear replay ID' : false);

        testWidgets('captures images', (tester) async {
          await tester.runAsync(() async {
            when(hub.configureScope(captureAny)).thenReturn(null);

            await pumpTestElement(tester);
            if (mockPlatform.isAndroid) {
              nextFrame({bool wait = true}) async {
                final future = mockAndroidRecorder.completer.future;
                await tester.pumpAndWaitUntil(future, requiredToComplete: wait);
              }

              await native.invokeFromNative(
                  'ReplayRecorder.start', replayConfig);

              await nextFrame();
              expect(mockAndroidRecorder.captured, isNotEmpty);
              final screenshot = mockAndroidRecorder.captured.first;
              expect(screenshot.width, replayConfig['width']);
              expect(screenshot.height, replayConfig['height']);

              await native.invokeFromNative('ReplayRecorder.pause');
              var count = mockAndroidRecorder.captured.length;

              await nextFrame(wait: false);
              await Future<void>.delayed(const Duration(milliseconds: 100));
              expect(mockAndroidRecorder.captured.length, equals(count));

              await nextFrame(wait: false);
              expect(mockAndroidRecorder.captured.length, equals(count));

              await native.invokeFromNative('ReplayRecorder.resume');

              await nextFrame();
              expect(mockAndroidRecorder.captured.length, greaterThan(count));

              await native.invokeFromNative('ReplayRecorder.stop');
              count = mockAndroidRecorder.captured.length;
              await Future<void>.delayed(const Duration(milliseconds: 100));
              await nextFrame(wait: false);
              expect(mockAndroidRecorder.captured.length, equals(count));
            } else if (mockPlatform.isIOS) {
              Future<void> captureAndVerify() async {
                final future = native.invokeFromNative(
                    'captureReplayScreenshot', replayConfig);
                final json = (await tester.pumpAndWaitUntil(future))
                    as Map<dynamic, dynamic>;

                expect(json['length'], greaterThan(3000));
                expect(json['address'], greaterThan(0));
                expect(json['width'], 640);
                expect(json['height'], 480);
                NativeMemory.fromJson(json).free();
              }

              await captureAndVerify();

              // Check everything works if session-replay rate is 0,
              // which causes replayId to be 0 as well.
              replayConfig['replayId'] = null;
              await captureAndVerify();
            } else {
              fail('unsupported platform');
            }
          });
        }, timeout: Timeout(Duration(seconds: 10)));
      });
    });
  }
}

class _MockAndroidReplayRecorder extends ScheduledScreenshotRecorder
    implements AndroidReplayRecorder {
  final captured = <Screenshot>[];
  var completer = Completer<void>();

  _MockAndroidReplayRecorder(super.config, super.options) {
    super.callback = (screenshot, _) async {
      captured.add(screenshot);
      completer.complete();
      completer = Completer<void>();
    };
  }

  @override
  Future<void> start() async {
    super.start();
  }
}
