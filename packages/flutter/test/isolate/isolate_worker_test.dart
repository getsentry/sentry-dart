@TestOn('vm')
library;

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
  });
}
