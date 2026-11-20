@TestOn('vm')
// ignore_for_file: invalid_use_of_internal_member
library;

import 'dart:async';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/isolate/isolate_worker.dart';
import 'package:sentry_flutter/src/native/java/android_replay_recorder.dart';

import '../mocks.dart';

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
  });
}

class Fixture {
  final options = defaultTestOptions();
  final workerMessages = <Object?>[];
  final _pendingSpawns = <Completer<Worker>>[];

  AndroidReplayRecorder getSut() => AndroidReplayRecorder(
    options,
    spawn: (config, entry) {
      final spawn = Completer<Worker>();
      _pendingSpawns.add(spawn);
      return spawn.future;
    },
  );

  /// Completes the oldest pending spawn with a worker whose inbox is recorded
  /// in [workerMessages].
  void completeSpawn() {
    final inbox = ReceivePort()..listen(workerMessages.add);
    addTearDown(inbox.close);
    final replies = ReceivePort();
    addTearDown(replies.close);
    _pendingSpawns.removeAt(0).complete(Worker(inbox.sendPort, replies));
  }
}
