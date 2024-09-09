// ignore_for_file: invalid_use_of_internal_member

@TestOn('vm')
library flutter_test;

import 'dart:async';
import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/event_processor/replay_event_processor.dart';
import 'package:sentry_flutter/src/native/factory.dart';
import 'package:sentry_flutter/src/native/sentry_native_binding.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';
import 'test_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final mockPlatform in [
    MockPlatform.android(),
    MockPlatform.iOs(),
  ]) {
    group('$SentryNativeBinding ($mockPlatform)', () {
      late SentryNativeBinding sut;
      late NativeChannelFixture native;
      late SentryFlutterOptions options;
      late MockHub hub;
      late FileSystem fs;
      late Directory replayDir;
      late final Map<String, dynamic> replayConfig;

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
          'frameRate': 10,
        };
      }

      setUp(() {
        hub = MockHub();

        fs = MemoryFileSystem.test();
        replayDir = fs.directory(replayConfig['directory'])
          ..createSync(recursive: true);

        options = defaultTestOptions()
          ..platformChecker = MockPlatformChecker(mockPlatform: mockPlatform)
          ..fileSystem = fs;

        native = NativeChannelFixture();
        when(native.handler('initNativeSdk', any))
            .thenAnswer((_) => Future.value());
        when(native.handler('closeNativeSdk', any))
            .thenAnswer((_) => Future.value());

        sut = createBinding(options, channel: native.channel);
      });

      tearDown(() async {
        await sut.close();
      });

      test('init sets $ReplayEventProcessor when error replay is enabled',
          () async {
        options.experimental.replay.onErrorSampleRate = 0.1;
        await sut.init(hub);

        expect(options.eventProcessors.map((e) => e.runtimeType.toString()),
            contains('$ReplayEventProcessor'));
      });

      test(
          'init does not set $ReplayEventProcessor when error replay is disabled',
          () async {
        await sut.init(hub);

        expect(options.eventProcessors.map((e) => e.runtimeType.toString()),
            isNot(contains('$ReplayEventProcessor')));
      });

      group('replay recorder', () {
        setUp(() async {
          options.experimental.replay.sessionSampleRate = 0.1;
          options.experimental.replay.onErrorSampleRate = 0.1;
          await sut.init(hub);
        });

        test('sets replay ID to context', () async {
          // verify there was no scope configured before
          verifyNever(hub.configureScope(any));

          // emulate the native platform invoking the method
          await native.invokeFromNative(
              mockPlatform.isAndroid
                  ? 'ReplayRecorder.start'
                  : 'captureReplayScreenshot',
              replayConfig);

          // verify the replay ID was set
          final closure =
              verify(hub.configureScope(captureAny)).captured.single;
          final scope = Scope(options);
          expect(scope.replayId, isNull);
          await closure(scope);
          expect(scope.replayId.toString(), replayConfig['replayId']);
        });

        test('clears replay ID from context', () async {
          // verify there was no scope configured before
          verifyNever(hub.configureScope(any));

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
            if (mockPlatform.isAndroid) {
              var callbackFinished = Completer<void>();

              nextFrame({bool wait = true}) async {
                final future = callbackFinished.future;
                tester.binding.scheduleFrame();
                await tester.pumpAndSettle(const Duration(seconds: 1));
                await future.timeout(Duration(milliseconds: wait ? 1000 : 100),
                    onTimeout: () {
                  if (wait) {
                    fail('native callback not called');
                  }
                });
              }

              imageInfo(File file) => file.readAsBytesSync().length;

              fileToImageMap(Iterable<File> files) =>
                  {for (var file in files) file.path: imageInfo(file)};

              final capturedImages = <String, int>{};
              when(native.handler('addReplayScreenshot', any))
                  .thenAnswer((invocation) async {
                final path =
                    invocation.positionalArguments[1]["path"] as String;
                capturedImages[path] = imageInfo(fs.file(path));
                callbackFinished.complete();
                callbackFinished = Completer<void>();
                return null;
              });

              fsImages() {
                final files = replayDir.listSync().map((f) => f as File);
                return fileToImageMap(files);
              }

              await pumpTestElement(tester);

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
              // configureScope() is called on iOS
              when(hub.configureScope(captureAny)).thenReturn(null);

              nextFrame() async {
                tester.binding.scheduleFrame();
                await Future<void>.delayed(const Duration(milliseconds: 100));
                await tester.pumpAndSettle(const Duration(seconds: 1));
              }

              await pumpTestElement(tester);
              await nextFrame();

              final imagaData = await native.invokeFromNative(
                  'captureReplayScreenshot', replayConfig) as ByteData;
              expect(imagaData.lengthInBytes, greaterThan(3000));
            } else {
              fail('unsupported platform');
            }
          });
        }, timeout: Timeout(Duration(seconds: 10)));
      });
    });
  }
}
