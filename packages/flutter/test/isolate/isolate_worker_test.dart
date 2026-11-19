@TestOn('vm')
library;

import 'dart:async';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/isolate/isolate_worker.dart';

class _EchoHandler extends WorkerHandler {
  @override
  Future<void> onMessage(Object? message) async {
    if (message is (SendPort, Object?)) {
      message.$1.send(message.$2);
    }
  }

  @override
  Future<Object?> onRequest(Object? payload) async => payload;
}

class _ErrorHandler extends WorkerHandler {
  @override
  Future<void> onMessage(Object? message) async {}

  @override
  Future<Object?> onRequest(Object? payload) async {
    throw Exception('boom');
  }
}

class _DelayHandler extends WorkerHandler {
  @override
  Future<void> onMessage(Object? message) async {}

  @override
  Future<Object?> onRequest(Object? payload) async {
    final milliseconds = payload as int;
    await Future<void>.delayed(Duration(milliseconds: milliseconds));
    return 'd:$milliseconds';
  }
}

class _DebugNameHandler extends WorkerHandler {
  @override
  Future<void> onMessage(Object? message) async {}

  @override
  Future<Object?> onRequest(Object? payload) async {
    return Isolate.current.debugName;
  }
}

/// On request, registers its own exit listener so a test can observe when
/// this worker isolate terminates.
class _SelfExitObserverHandler extends WorkerHandler {
  @override
  Future<void> onMessage(Object? message) async {}

  @override
  Future<Object?> onRequest(Object? payload) async {
    if (payload is SendPort) {
      Isolate.current.addOnExitListener(payload, response: 'worker_exited');
    }
    return 'registered';
  }
}

void _entryEcho((SendPort, WorkerConfig) init) {
  final (host, config) = init;
  runWorker(config, host, _EchoHandler());
}

void _entryError((SendPort, WorkerConfig) init) {
  final (host, config) = init;
  runWorker(config, host, _ErrorHandler());
}

void _entryDelay((SendPort, WorkerConfig) init) {
  final (host, config) = init;
  runWorker(config, host, _DelayHandler());
}

void _entryDebugName((SendPort, WorkerConfig) init) {
  final (host, config) = init;
  runWorker(config, host, _DebugNameHandler());
}

void _entrySelfExitObserver((SendPort, WorkerConfig) init) {
  final (host, config) = init;
  runWorker(config, host, _SelfExitObserverHandler());
}

/// Plays the role of AndroidCoreWorker's owning isolate: spawns a worker,
/// calls [Worker.closeOnOwnerExit] on it, then signals readiness.
Future<void> _ownerEntry(({SendPort ready, SendPort observed}) ports) async {
  final worker = await spawnWorker(
    const WorkerConfig(
      debug: true,
      diagnosticLevel: SentryLevel.debug,
      debugName: 'OwnerExitWorker',
    ),
    _entrySelfExitObserver,
  );
  // Round trip, not a fire-and-forget send: guarantees the worker has
  // registered its self-exit listener before this isolate is killed.
  await worker.request(ports.observed);
  worker.closeOnOwnerExit();
  ports.ready.send('ready');
}

/// Set inside the worker isolate by [_ShutdownProbeHandler], so the exit
/// request functions below can report to the test.
SendPort? _probeEvents;

/// Reports what happens around shutdown to the port it receives in a
/// request, and answers that request with its isolate's control port and
/// terminate capability.
class _ShutdownProbeHandler extends WorkerHandler {
  @override
  Future<void> onMessage(Object? message) async {
    _probeEvents?.send('message:$message');
  }

  @override
  Future<Object?> onRequest(Object? payload) async {
    if (payload is SendPort) {
      _probeEvents = payload;
      Isolate.current.addOnExitListener(payload, response: 'exited');
    }
    return (Isolate.current.controlPort, Isolate.current.terminateCapability);
  }

  @override
  void onShutdown() => _probeEvents?.send('onShutdown');
}

bool _grantExit(int exitToken) {
  _probeEvents?.send('requestExit:$exitToken');
  return true;
}

bool _denyExit(int exitToken) {
  _probeEvents?.send('requestExit:$exitToken');
  return false;
}

bool _failExitRequest(int exitToken) {
  _probeEvents?.send('requestExit:$exitToken');
  throw StateError('exit request failed');
}

void _entryGrantExit((SendPort, WorkerConfig) init) {
  final (host, config) = init;
  runWorker(config, host, _ShutdownProbeHandler(), requestExit: _grantExit);
}

void _entryDenyExit((SendPort, WorkerConfig) init) {
  final (host, config) = init;
  runWorker(config, host, _ShutdownProbeHandler(), requestExit: _denyExit);
}

void _entryFailExitRequest((SendPort, WorkerConfig) init) {
  final (host, config) = init;
  runWorker(
    config,
    host,
    _ShutdownProbeHandler(),
    requestExit: _failExitRequest,
  );
}

class _RecordingHandler extends WorkerHandler {
  final messages = <Object?>[];
  final requests = <Object?>[];
  var shutdownCount = 0;

  @override
  void onMessage(Object? message) => messages.add(message);

  @override
  Object? onRequest(Object? payload) {
    requests.add(payload);
    return 'answer';
  }

  @override
  void onShutdown() => shutdownCount++;
}

const _shutdownConfig = WorkerConfig(
  debug: true,
  diagnosticLevel: SentryLevel.debug,
  debugName: 'ShutdownWorker',
);

void main() {
  group('Worker isolate', () {
    test('request/response echoes', () async {
      final worker = await spawnWorker(
        const WorkerConfig(
          debug: true,
          diagnosticLevel: SentryLevel.debug,
          debugName: 'EchoWorker',
        ),
        _entryEcho,
      );
      try {
        final result = await worker.request('ping');
        expect(result, 'ping');
      } finally {
        worker.close();
      }
    });

    test('fire-and-forget can ack via SendPort', () async {
      final worker = await spawnWorker(
        const WorkerConfig(
          debug: true,
          diagnosticLevel: SentryLevel.debug,
          debugName: 'AckWorker',
        ),
        _entryEcho,
      );
      try {
        final rp = ReceivePort();
        worker.send((rp.sendPort, 'ok'));
        expect(await rp.first, 'ok');
        rp.close();
      } finally {
        worker.close();
      }
    });

    test('request errors propagate as RemoteError', () async {
      final worker = await spawnWorker(
        const WorkerConfig(
          debug: true,
          diagnosticLevel: SentryLevel.debug,
          debugName: 'ErrorWorker',
        ),
        _entryError,
      );
      try {
        expect(() => worker.request('any'), throwsA(isA<RemoteError>()));
      } finally {
        worker.close();
      }
    });

    test('concurrent requests are correlated', () async {
      final worker = await spawnWorker(
        const WorkerConfig(
          debug: true,
          diagnosticLevel: SentryLevel.debug,
          debugName: 'DelayWorker',
        ),
        _entryDelay,
      );
      try {
        final futures = <Future<Object?>>[
          worker.request(50),
          worker.request(10),
          worker.request(30),
        ];
        final results = await Future.wait(futures);
        expect(results, ['d:50', 'd:10', 'd:30']);
      } finally {
        worker.close();
      }
    });

    test('close rejects new requests; in-flight completes', () async {
      final worker = await spawnWorker(
        const WorkerConfig(
          debug: true,
          diagnosticLevel: SentryLevel.debug,
          debugName: 'CloseWorker',
        ),
        _entryDelay,
      );
      try {
        final inFlight = worker.request(30);
        worker.close();
        expect(() => worker.request(1), throwsA(isA<StateError>()));
        expect(await inFlight, 'd:30');
      } finally {
        // idempotent
        worker.close();
      }
    });

    test('send after close is a no-op and does not throw', () async {
      final worker = await spawnWorker(
        const WorkerConfig(
          debug: true,
          diagnosticLevel: SentryLevel.debug,
          debugName: 'NoThrowSendAfterCloseWorker',
        ),
        _entryEcho,
      );
      worker.close();
      // Fire-and-forget send should be safe and not throw even after close.
      expect(() => worker.send('ignored'), returnsNormally);
    });

    test(
      'worker shuts itself down when its owner isolate exits abruptly',
      () async {
        final ready = ReceivePort();
        final observed = ReceivePort();

        final owner = await Isolate.spawn(_ownerEntry, (
          ready: ready.sendPort,
          observed: observed.sendPort,
        ));
        addTearDown(() {
          ready.close();
          observed.close();
        });

        // Owner has spawned its worker, called closeOnOwnerExit() on it, and
        // the worker has confirmed its own self-exit listener is registered.
        await ready.first;

        // Simulate abrupt engine/isolate-group teardown - not a graceful Dart
        // return from the owner's entry point.
        owner.kill(priority: Isolate.immediate);

        // The runtime should still deliver the shutdown message to the worker
        // from its now-dead owner, causing the worker to close its own inbox
        // and terminate, which fires the worker's self-exit listener.
        final result = await observed.first.timeout(
          const Duration(seconds: 10),
        );
        expect(result, 'worker_exited');
      },
    );

    test('debugName propagates to worker isolate', () async {
      const debugName = 'DebugNameWorker';
      final worker = await spawnWorker(
        const WorkerConfig(
          debug: true,
          diagnosticLevel: SentryLevel.debug,
          debugName: debugName,
        ),
        _entryDebugName,
      );
      try {
        final result = await worker.request(null);
        expect(result, debugName);
      } finally {
        worker.close();
      }
    });

    group('when closed with an exit token', () {
      test('handles earlier messages, requests the exit, then exits', () async {
        final events = ReceivePort();
        addTearDown(events.close);
        final worker = await spawnWorker(_shutdownConfig, _entryGrantExit);
        await worker.request(events.sendPort);

        worker.send('a');
        worker.close(exitToken: 7);

        expect(await events.take(4).toList(), [
          'message:a',
          'onShutdown',
          'requestExit:7',
          'exited',
        ]);
      });

      // Closes a worker spawned from [entry] with an exit token and expects
      // it to be alive afterwards, without having exited.
      Future<void> expectStaysAlive(WorkerEntry entry) async {
        final events = ReceivePort();
        addTearDown(events.close);
        final received = <Object?>[];
        final refused = Completer<void>();
        final exited = Completer<void>();
        events.listen((event) {
          received.add(event);
          if (event == 'requestExit:7') refused.complete();
          if (event == 'exited') exited.complete();
        });
        final worker = await spawnWorker(_shutdownConfig, entry);
        final (controlPort, terminateCapability) =
            await worker.request(events.sendPort) as (SendPort, Capability?);
        final isolate = Isolate(
          controlPort,
          terminateCapability: terminateCapability,
        );
        addTearDown(() async {
          isolate.kill(priority: Isolate.immediate);
          // Fails the test if the worker is left behind.
          await exited.future.timeout(const Duration(seconds: 10));
        });

        worker.close(exitToken: 7);
        await refused.future;

        // Answered only once the worker is back in its event loop, i.e. after
        // it would have closed its inbox and exited. A worker that has exited
        // does not answer at all.
        final pong = ReceivePort();
        addTearDown(pong.close);
        isolate.ping(
          pong.sendPort,
          response: 'pong',
          priority: Isolate.beforeNextEvent,
        );
        await Future.any([pong.first, exited.future]);
        await pumpEventQueue();
        expect(received, ['onShutdown', 'requestExit:7']);
      }

      test(
        'stays alive when the exit request is denied',
        () => expectStaysAlive(_entryDenyExit),
      );

      test(
        'stays alive when the exit request throws',
        () => expectStaysAlive(_entryFailExitRequest),
      );

      test('ignores everything after the exit request was denied', () async {
        // Runs the worker loop in the test isolate so delivery is
        // deterministic. Its inbox stays open, as it would in a parked
        // worker; the test isolate is torn down with the test file.
        final handler = _RecordingHandler();
        final inbox = Completer<SendPort>();
        final answers = <Object?>[];
        final host = ReceivePort();
        addTearDown(host.close);
        host.listen((message) {
          if (message is SendPort) {
            inbox.complete(message);
          } else {
            answers.add(message);
          }
        });
        runWorker(
          _shutdownConfig,
          host.sendPort,
          handler,
          requestExit: (_) => false,
        );
        final replies = ReceivePort();
        addTearDown(replies.close);
        final worker = Worker(await inbox.future, replies);

        worker.send('before');
        worker.close(exitToken: 7);
        worker.send('after');
        // Sent as the host would send them: a closed Worker sends neither.
        worker.send('_shutdown_');
        worker.send((1, 'request'));
        await pumpEventQueue();

        expect(handler.messages, ['before']);
        expect(handler.requests, isEmpty);
        expect(answers, isEmpty);
        // A second shutdown would close the inbox, which ends the isolate.
        expect(handler.shutdownCount, 1);
      });
    });

    test('closed without an exit token exits without requesting it', () async {
      final events = ReceivePort();
      addTearDown(events.close);
      final worker = await spawnWorker(_shutdownConfig, _entryGrantExit);
      await worker.request(events.sendPort);

      worker.close();

      expect(await events.take(2).toList(), ['onShutdown', 'exited']);
    });

    group('when closed for an engine detach', () {
      late ReceivePort inbox;
      late Worker worker;

      setUp(() {
        inbox = ReceivePort();
        addTearDown(inbox.close);
        final replies = ReceivePort();
        addTearDown(replies.close);
        worker = Worker(inbox.sendPort, replies);
      });

      test('arms the exit and closes with the token', () async {
        final armedTokens = <int>[];

        worker.closeForEngineDetach(7, armedTokens.add);

        expect(armedTokens, [7]);
        expect(await inbox.first, ('_shutdown_', 7));
      });

      test('still closes with the token when arming fails', () async {
        worker.closeForEngineDetach(7, (_) => throw StateError('arm failed'));

        expect(await inbox.first, ('_shutdown_', 7));
      });
    });
  });
}
