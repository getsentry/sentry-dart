// ignore_for_file: invalid_use_of_internal_member

@TestOn('vm')
library flutter_test;

import 'dart:async';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/factory.dart';
import 'package:sentry_flutter/src/native/native_memory.dart';
import 'package:sentry_flutter/src/native/sentry_native_binding.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';
import '../screenshot/test_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final mockPlatform in [
    MockPlatform.android(),
    MockPlatform.iOs(),
  ]) {
    group('$SentryNativeBinding (${mockPlatform.operatingSystem})', () {
      late SentryNativeBinding sut;
      late NativeChannelFixture native;
      late SentryFlutterOptions options;
      late MockHub hub;
      late FileSystem fs;
      late Directory replayDir;
      late Map<String, dynamic> replayConfig;

      setUp(() {
        if (mockPlatform.isIOS) {
          replayConfig = {
            'replayId': '123',
            'directory': 'dir',
          };
        } else if (mockPlatform.isAndroid) {
          replayConfig = {
            'replayId': '123',
            'directory': 'dir',
            'width': 800,
            'height': 600,
            'frameRate': 1000,
          };
        }

        hub = MockHub();

        fs = MemoryFileSystem.test();
        replayDir = fs.directory(replayConfig['directory'])
          ..createSync(recursive: true);

        native = NativeChannelFixture();

        options =
            defaultTestOptions(MockPlatformChecker(mockPlatform: mockPlatform))
              ..fileSystem = fs
              ..methodChannel = native.channel;

        sut = createBinding(options);
      });

      tearDown(() async {
        await sut.close();
      });

      group('replay recorder', () {
        setUp(() async {
          options.experimental.replay.sessionSampleRate = 0.1;
          options.experimental.replay.onErrorSampleRate = 0.1;
          await sut.init(hub);
        });

        testWidgets('sets replayID to context', (tester) async {
          await tester.runAsync(() async {
            // verify there was no scope configured before
            verifyNever(hub.configureScope(any));
            when(hub.configureScope(captureAny)).thenReturn(null);

            // emulate the native platform invoking the method
            final future = native.invokeFromNative(
                mockPlatform.isAndroid
                    ? 'ReplayRecorder.start'
                    : 'captureReplayScreenshot',
                replayConfig);
            await tester.pumpAndSettle(const Duration(seconds: 1));
            await future;

            // verify the replay ID was set
            final closure =
                verify(hub.configureScope(captureAny)).captured.single;
            final scope = Scope(options);
            expect(scope.replayId, isNull);
            await closure(scope);
            expect(scope.replayId.toString(), replayConfig['replayId']);
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
            pumpAndSettle() => tester.pumpAndSettle(const Duration(seconds: 1));

            if (mockPlatform.isAndroid) {
              var callbackFinished = Completer<void>();

              nextFrame({bool wait = true}) async {
                final future = callbackFinished.future;
                await pumpAndSettle();
                await future.timeout(Duration(milliseconds: wait ? 1000 : 100),
                    onTimeout: () {
                  if (wait) {
                    fail('native callback not called');
                  }
                });
              }

              imageSizeBytes(File file) => file.readAsBytesSync().length;

              final capturedImages = <String, int>{};
              when(native.handler('addReplayScreenshot', any))
                  .thenAnswer((invocation) {
                final path =
                    invocation.positionalArguments[1]["path"] as String;
                capturedImages[path] = imageSizeBytes(fs.file(path));
                callbackFinished.complete();
                callbackFinished = Completer<void>();
                return null;
              });

              fsImages() {
                final files = replayDir.listSync().map((f) => f as File);
                return {for (var f in files) f.path: imageSizeBytes(f)};
              }

              await nextFrame(wait: false);
              expect(fsImages(), isEmpty);
              verifyNever(native.handler('addReplayScreenshot', any));

              await native.invokeFromNative(
                  'ReplayRecorder.start', replayConfig);

              await nextFrame();
              expect(fsImages().values, isNotEmpty);
              final size = fsImages().values.first;
              expect(size, greaterThan(3000));
              expect(fsImages().values, [size]);
              expect(capturedImages, equals(fsImages()));

              await nextFrame();
              fsImages().values.forEach((s) => expect(s, size));
              expect(capturedImages, equals(fsImages()));

              await native.invokeFromNative('ReplayRecorder.pause');
              var count = capturedImages.length;

              await nextFrame(wait: false);
              await Future<void>.delayed(const Duration(milliseconds: 100));
              fsImages().values.forEach((s) => expect(s, size));
              expect(capturedImages, equals(fsImages()));
              expect(capturedImages.length, count);

              await nextFrame(wait: false);
              fsImages().values.forEach((s) => expect(s, size));
              expect(capturedImages, equals(fsImages()));
              expect(capturedImages.length, count);

              await native.invokeFromNative('ReplayRecorder.resume');

              await nextFrame();
              fsImages().values.forEach((s) => expect(s, size));
              expect(capturedImages, equals(fsImages()));
              expect(capturedImages.length, greaterThan(count));

              await native.invokeFromNative('ReplayRecorder.stop');
              count = capturedImages.length;
              await Future<void>.delayed(const Duration(milliseconds: 100));
              await nextFrame(wait: false);
              fsImages().values.forEach((s) => expect(s, size));
              expect(capturedImages, equals(fsImages()));
              expect(capturedImages.length, count);
            } else if (mockPlatform.isIOS) {
              Future<void> captureAndVerify() async {
                final future = native.invokeFromNative(
                    'captureReplayScreenshot', replayConfig);
                await pumpAndSettle();
                final json = (await future) as Map<dynamic, dynamic>;

                expect(json['length'], greaterThan(3000));
                expect(json['address'], greaterThan(0));
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
