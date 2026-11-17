@TestOn('vm')
// ignore_for_file: invalid_use_of_internal_member
library;

import 'dart:async';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/isolate/isolate_worker.dart';
import 'package:sentry_flutter/src/native/java/android_replay_recorder.dart';
import 'package:sentry_flutter/src/replay/scheduled_recorder_config.dart';

import '../mocks.dart';
import '../replay/replay_test_util.dart';
import '../screen_capture/test_widget.dart';

void main() {
  group('$AndroidReplayRecorder', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('closes the worker when stopped while it is still spawning', () async {
      final sut = fixture.getSut();

      final started = sut.start();
      await sut.stop();
      fixture.completeSpawn();
      await started;
      await pumpEventQueue();

      expect(fixture.workerMessages, ['_shutdown_']);
    });

    test(
      'closes the first worker when restarted while it is still spawning',
      () async {
        final sut = fixture.getSut();

        final firstStarted = sut.start();
        await sut.stop();
        final secondStarted = sut.start();

        fixture.completeSpawn();
        await firstStarted;
        await pumpEventQueue();
        expect(fixture.workerMessages, ['_shutdown_']);

        fixture.completeSpawn();
        await secondStarted;
        await pumpEventQueue();
        expect(fixture.workerMessages, ['_shutdown_']);
      },
    );

    test(
      'closes the first worker when started again while it is still spawning',
      () async {
        final sut = fixture.getSut();

        final firstStarted = sut.start();
        final secondStarted = sut.start();

        fixture.completeSpawn();
        await firstStarted;
        await pumpEventQueue();
        expect(fixture.workerMessages, ['_shutdown_']);

        fixture.completeSpawn();
        await secondStarted;
        await pumpEventQueue();
        expect(fixture.workerMessages, ['_shutdown_']);
      },
    );

    group('when the engine detaches', () {
      test(
        'arms the exit and closes the running worker with the token',
        () async {
          final sut = fixture.getSut();
          final started = sut.start();
          fixture.completeSpawn();
          await started;

          sut.closeForEngineDetach(7);
          await pumpEventQueue();

          expect(fixture.armedTokens, [7]);
          expect(fixture.workerMessages, [('_shutdown_', 7)]);
        },
      );

      test('does not arm the exit when never started', () {
        final sut = fixture.getSut();

        sut.closeForEngineDetach(7);

        expect(fixture.armedTokens, isEmpty);
      });

      test(
        'closes the worker with the token without arming while it is still spawning',
        () async {
          final sut = fixture.getSut();
          final started = sut.start();

          sut.closeForEngineDetach(7);
          fixture.completeSpawn();
          await started;
          await pumpEventQueue();

          expect(fixture.armedTokens, isEmpty);
          expect(fixture.workerMessages, [('_shutdown_', 7)]);
        },
      );

      test(
        'still closes the worker with the token when arming fails',
        () async {
          final sut = fixture.getSut(
            armExit: (_) => throw StateError('arm failed'),
          );
          final started = sut.start();
          fixture.completeSpawn();
          await started;

          sut.closeForEngineDetach(7);
          await pumpEventQueue();

          expect(fixture.workerMessages, [('_shutdown_', 7)]);
        },
      );

      test('does not spawn a worker when started afterwards', () async {
        final sut = fixture.getSut();

        sut.closeForEngineDetach(7);
        final started = sut.start();

        expect(fixture.pendingSpawnCount, 0);
        await started;
      });

      test(
        'closes the worker with the token while stop waits for its reply',
        () async {
          final sut = fixture.getSut();
          final started = sut.start();
          fixture.completeSpawn();
          await started;
          final stopped = sut.stop();
          await pumpEventQueue();

          sut.closeForEngineDetach(7);
          fixture.answerRequests();
          await stopped;
          await pumpEventQueue();

          expect(fixture.armedTokens, [7]);
          // The close request of stop(), then only the shutdown of the detach.
          expect(fixture.workerMessages, [
            isA<(int, Object?)>(),
            ('_shutdown_', 7),
          ]);
        },
      );

      testWidgets('stops capturing', (tester) async {
        await tester.runAsync(() async {
          final sut = fixture.getSut();
          await fixture.startCapturing(tester, sut);
          final screenshotAdded = Completer<void>();
          sut.onScreenshotAddedForTest = screenshotAdded.complete;

          sut.closeForEngineDetach(7);
          tester.binding.scheduleFrame();
          await tester.pumpAndWaitUntil(
            screenshotAdded.future,
            requiredToComplete: false,
          );

          expect(screenshotAdded.isCompleted, isFalse);
        });
      });

      testWidgets('drops a screenshot that is in flight', (tester) async {
        await tester.runAsync(() async {
          final sut = fixture.getSut();
          await fixture.startCapturing(tester, sut);
          final screenshotAdded = Completer<void>();
          sut.onScreenshotAddedForTest = () {
            sut.closeForEngineDetach(7);
            screenshotAdded.complete();
          };

          tester.binding.scheduleFrame();
          await tester.pumpAndWaitUntil(screenshotAdded.future);
          // Waits for the capture that is in flight.
          await sut.stop();
          await pumpEventQueue();

          expect(fixture.workerMessages, [('_shutdown_', 7)]);
        });
      });
    });
  });
}

class Fixture {
  final options = defaultTestOptions();
  final workerMessages = <Object?>[];
  final armedTokens = <int>[];
  final _pendingSpawns = <Completer<Worker>>[];
  final _unansweredRequests = <(SendPort, int)>[];

  /// The number of spawns the recorder has requested that [completeSpawn]
  /// has not completed yet.
  int get pendingSpawnCount => _pendingSpawns.length;

  AndroidReplayRecorder getSut({void Function(int token)? armExit}) =>
      AndroidReplayRecorder(
        options,
        spawn: (config, entry) {
          final spawn = Completer<Worker>();
          _pendingSpawns.add(spawn);
          return spawn.future;
        },
        armExit: armExit ?? armedTokens.add,
      );

  /// Starts [sut] with a spawned worker and a configuration, so that it
  /// captures the test widget on the next frame. Needs
  /// [WidgetTester.runAsync].
  Future<void> startCapturing(
    WidgetTester tester,
    AndroidReplayRecorder sut,
  ) async {
    await pumpTestElement(tester);
    await sut.onConfigurationChanged(
      ScheduledScreenshotRecorderConfig(
        width: 1000,
        height: 1000,
        frameRate: 1000,
      ),
    );
    final started = sut.start();
    completeSpawn();
    await started;
  }

  /// Completes the oldest pending spawn with a worker whose inbox is recorded
  /// in [workerMessages].
  void completeSpawn() {
    final replies = ReceivePort();
    addTearDown(replies.close);
    final inbox = ReceivePort()
      ..listen((message) {
        workerMessages.add(message);
        if (message case (final int id, _)) {
          _unansweredRequests.add((replies.sendPort, id));
        }
      });
    addTearDown(inbox.close);
    _pendingSpawns.removeAt(0).complete(Worker(inbox.sendPort, replies));
  }

  /// Answers every request the workers have received so far. They answer
  /// nothing on their own.
  void answerRequests() {
    for (final (host, id) in _unansweredRequests) {
      host.send((id, null));
    }
    _unansweredRequests.clear();
  }
}
