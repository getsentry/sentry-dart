// ignore_for_file: invalid_use_of_internal_member

@TestOn('vm')
library flutter_test;

import 'dart:async';

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

  for (var mockPlatform in [
    MockPlatform.android(),
  ]) {
    group('$SentryNativeBinding ($mockPlatform)', () {
      late SentryNativeBinding sut;
      late NativeChannelFixture native;
      late SentryFlutterOptions options;
      late MockHub hub;
      late FileSystem fs;
      late Directory replayDir;
      final replayConfig = {
        'replayId': '123',
        'directory': 'dir',
        'width': 1000,
        'height': 1000,
        'frameRate': 1000,
      };

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
        options.experimental.replay.errorSampleRate = 0.1;
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
          options.experimental.replay.errorSampleRate = 0.1;
          await sut.init(hub);
        });

        test('start() sets replay ID to context', () async {
          // verify there was no scope configured before
          verifyNever(hub.configureScope(any));

          // emulate the native platform invoking the method
          await native.invokeFromNative('ReplayRecorder.start', replayConfig);

          // verify the replay ID was set
          final closure =
              verify(hub.configureScope(captureAny)).captured.single;
          final scope = Scope(options);
          expect(scope.replayId, isNull);
          await closure(scope);
          expect(scope.replayId.toString(), replayConfig['replayId']);
        });

        test('stop() clears replay ID from context', () async {
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
        });

        testWidgets('captures images', (tester) async {
          await tester.runAsync(() async {
            var callbackFinished = Completer<void>();

            nextFrame({bool wait = true}) async {
              tester.binding.scheduleFrame();
              await Future<void>.delayed(const Duration(milliseconds: 100));
              await tester.pumpAndSettle(const Duration(seconds: 1));
              await callbackFinished.future.timeout(
                  Duration(milliseconds: wait ? 1000 : 100), onTimeout: () {
                if (wait) {
                  fail('native callback not called');
                }
              });
              callbackFinished = Completer<void>();
            }

            imageInfo(File file) => file.readAsBytesSync().length;

            fileToImageMap(Iterable<File> files) =>
                {for (var file in files) file.path: imageInfo(file)};

            final capturedImages = <String, int>{};
            when(native.handler('addReplayScreenshot', any))
                .thenAnswer((invocation) async {
              callbackFinished.complete();
              final path = invocation.positionalArguments[1]["path"] as String;
              capturedImages[path] = imageInfo(fs.file(path));
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

            await native.invokeFromNative('ReplayRecorder.start', replayConfig);

            await nextFrame();
            expect(fsImages().values, [5378]);
            expect(capturedImages, equals(fsImages()));

            await nextFrame();
            expect(fsImages().values, [5378, 5378]);
            expect(capturedImages, equals(fsImages()));

            await native.invokeFromNative('ReplayRecorder.stop');

            await nextFrame(wait: false);
            expect(fsImages().values, [5378, 5378]);
            expect(capturedImages, equals(fsImages()));

            await nextFrame(wait: false);
            expect(fsImages().values, [5378, 5378]);
            expect(capturedImages, equals(fsImages()));
          });
        }, timeout: Timeout(Duration(seconds: 10)));
      });
    });
  }
}
