@TestOn('vm')
// ignore_for_file: invalid_use_of_internal_member
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/isolate/isolate_worker.dart';
import 'package:sentry_flutter/src/native/java/android_core_worker.dart';

void main() {
  group('AndroidCoreWorker host behavior', () {
    test('logs when sending envelopes in main isolate', () {
      final options = SentryFlutterOptions();
      final logs = <(SentryLevel, String)>[];
      SentryInternalLogger.configure(
        isEnabled: true,
        minLevel: SentryLevel.debug,
        logOutput: ({
          required String name,
          required SentryLevel level,
          required String message,
          Object? error,
          StackTrace? stackTrace,
        }) {
          logs.add((level, message.toString()));
        },
      );

      final worker = AndroidCoreWorker(options);
      worker.captureEnvelope(Uint8List.fromList([1, 2, 3]), false);

      expect(
        logs.any((e) =>
            e.$1 == SentryLevel.info &&
            e.$2.contains(
                'captureEnvelope called before core worker started: sending envelope in main isolate instead')),
        isTrue,
      );
    });

    test('close is a no-op when not started', () {
      final options = SentryFlutterOptions();
      final worker = AndroidCoreWorker(options);
      expect(() => worker.close(), returnsNormally);
      expect(() => worker.close(), returnsNormally);
    });

    test('start is a no-op when already started', () async {
      final options = SentryFlutterOptions();
      options.debug = true;
      options.diagnosticLevel = SentryLevel.debug;

      var spawnCount = 0;
      Future<Worker> fakeSpawn(WorkerConfig config, WorkerEntry entry) async {
        spawnCount++;
        final inbox = ReceivePort();
        addTearDown(() => inbox.close());
        final replies = ReceivePort();
        return Worker(inbox.sendPort, replies);
      }

      final worker = AndroidCoreWorker(options, spawn: fakeSpawn);

      await worker.start();
      await worker.start();
      expect(spawnCount, 1);

      worker.close();
      spawnCount = 0;

      await worker.start();
      expect(spawnCount, 0);

      // Close twice should be safe.
      expect(() => worker.close(), returnsNormally);
      expect(() => worker.close(), returnsNormally);
    });

    test('logs when start fails', () async {
      final options = SentryFlutterOptions();
      final logs = <(SentryLevel, String)>[];
      SentryInternalLogger.configure(
        isEnabled: true,
        minLevel: SentryLevel.debug,
        logOutput: ({
          required String name,
          required SentryLevel level,
          required String message,
          Object? error,
          StackTrace? stackTrace,
        }) {
          logs.add((level, message.toString()));
        },
      );

      Future<Worker> fakeSpawn(WorkerConfig config, WorkerEntry entry) async {
        throw StateError('spawn failed');
      }

      final worker = AndroidCoreWorker(options, spawn: fakeSpawn);
      await worker.start();

      expect(
        logs.any((e) =>
            e.$1 == SentryLevel.error &&
            e.$2.contains('Failed to start Android core worker')),
        isTrue,
      );
    });

    test('close waits for in-flight start', () async {
      final options = SentryFlutterOptions();
      final spawnCompleter = Completer<Worker>();
      late ReceivePort inbox;
      late ReceivePort replies;

      Future<Worker> fakeSpawn(WorkerConfig config, WorkerEntry entry) {
        inbox = ReceivePort();
        addTearDown(inbox.close);
        replies = ReceivePort();
        addTearDown(replies.close);
        return spawnCompleter.future;
      }

      final worker = AndroidCoreWorker(options, spawn: fakeSpawn);
      unawaited(Future<void>.value(worker.start()));

      final closeFuture = Future<void>.value(worker.close());
      var closeCompleted = false;
      unawaited(closeFuture.then((_) => closeCompleted = true));

      await pumpEventQueue();
      expect(closeCompleted, isFalse);

      spawnCompleter.complete(Worker(inbox.sendPort, replies));

      await closeFuture;
      expect(closeCompleted, isTrue);
      expect(await inbox.first, '_shutdown_');
    });

    test('sends envelope capture request after start', () async {
      final options = SentryFlutterOptions();
      options.debug = true;
      options.diagnosticLevel = SentryLevel.debug;

      final inboxes = <ReceivePort>[];
      Future<Worker> fakeSpawn(WorkerConfig config, WorkerEntry entry) async {
        final inbox = ReceivePort();
        inboxes.add(inbox);
        addTearDown(() => inbox.close());
        final replies = ReceivePort();
        return Worker(inbox.sendPort, replies);
      }

      final worker = AndroidCoreWorker(options, spawn: fakeSpawn);
      await worker.start();

      final payload = Uint8List.fromList([4, 5, 6]);
      worker.captureEnvelope(payload, true);

      final msg = await inboxes.last.first as dynamic;
      expect(msg.containsUnhandledException, true);
      final transferable = msg.envelopeData as TransferableTypedData;
      final data = transferable.materialize().asUint8List();
      expect(data, [4, 5, 6]);

      worker.close();
    });

    test('uses expected WorkerConfig', () async {
      final options = SentryFlutterOptions();
      options.debug = true;
      options.diagnosticLevel = SentryLevel.debug;

      WorkerConfig? seenConfig;
      Future<Worker> fakeSpawn(WorkerConfig config, WorkerEntry entry) async {
        seenConfig = config;
        final inbox = ReceivePort();
        addTearDown(() => inbox.close());
        final replies = ReceivePort();
        return Worker(inbox.sendPort, replies);
      }

      final worker = AndroidCoreWorker(options, spawn: fakeSpawn);
      await worker.start();

      expect(seenConfig, isNotNull);
      expect(seenConfig!.debugName, 'SentryAndroidCoreWorker');
      expect(seenConfig!.debug, options.debug);
      expect(seenConfig!.diagnosticLevel, options.diagnosticLevel);

      worker.close();
    });

    test('sends envelope capture requests sequentially with flags', () async {
      final options = SentryFlutterOptions();
      options.debug = true;
      options.diagnosticLevel = SentryLevel.debug;

      final inboxes = <ReceivePort>[];
      Future<Worker> fakeSpawn(WorkerConfig config, WorkerEntry entry) async {
        final inbox = ReceivePort();
        inboxes.add(inbox);
        addTearDown(() => inbox.close());
        final replies = ReceivePort();
        return Worker(inbox.sendPort, replies);
      }

      final worker = AndroidCoreWorker(options, spawn: fakeSpawn);
      await worker.start();

      worker.captureEnvelope(Uint8List.fromList([10]), true);
      worker.captureEnvelope(Uint8List.fromList([11]), false);

      final inbox = inboxes.last;
      final msgs = await inbox.take(2).toList();
      final msg1 = msgs[0] as dynamic;
      final msg2 = msgs[1] as dynamic;

      expect(msg1.containsUnhandledException, true);
      expect(msg2.containsUnhandledException, false);

      final t1 = msg1.envelopeData as TransferableTypedData;
      final t2 = msg2.envelopeData as TransferableTypedData;
      final data1 = t1.materialize().asUint8List();
      final data2 = t2.materialize().asUint8List();
      expect(data1, [10]);
      expect(data2, [11]);

      worker.close();
    });

    test('requests debug images by instruction addresses', () async {
      final fixture = _Fixture();
      final worker = fixture.getSut();
      await worker.start();

      final resultFuture = worker.loadDebugImages(SentryStackTrace(frames: [
        SentryStackFrame(instructionAddr: '0x1'),
        SentryStackFrame(),
      ]));

      final (id, payload) = await fixture.nextRequest;
      expect((payload as dynamic).instructionAddresses, ['0x1']);
      fixture.respond(id, [
        {'type': 'elf', 'debug_id': 'debug-id'}
      ]);

      final result = await resultFuture;
      expect(result, hasLength(1));
      expect(result!.first.type, 'elf');
      expect(result.first.debugId, 'debug-id');
    });

    test('returns null when debug image request fails', () async {
      final fixture = _Fixture();
      final worker = fixture.getSut();
      await worker.start();

      final resultFuture = worker.loadDebugImages(SentryStackTrace(frames: [
        SentryStackFrame(instructionAddr: '0x1'),
      ]));

      final (id, _) = await fixture.nextRequest;
      fixture.respondError(id);

      expect(await resultFuture, isNull);
    });

    test('requests native contexts', () async {
      final fixture = _Fixture();
      final worker = fixture.getSut();
      await worker.start();

      final resultFuture = worker.loadContexts();

      final (id, payload) = await fixture.nextRequest;
      expect(payload.runtimeType.toString(), '_LoadContextsRequest');
      fixture.respond(id, {
        'contexts': {'fixture': true}
      });

      expect(await resultFuture, {
        'contexts': {'fixture': true}
      });
    });

    test('returns null when native contexts request fails', () async {
      final fixture = _Fixture();
      final worker = fixture.getSut();
      await worker.start();

      final resultFuture = worker.loadContexts();

      final (id, _) = await fixture.nextRequest;
      fixture.respondError(id);

      expect(await resultFuture, isNull);
    });

    test('sends breadcrumb update and awaits response', () async {
      final fixture = _Fixture();
      final worker = fixture.getSut();
      await worker.start();

      final payload = await fixture.expectPendingRequest(
        worker.addBreadcrumb(Breadcrumb(message: 'crumb')),
      );

      expect((payload as dynamic).breadcrumb['message'], 'crumb');
    });

    test('normalizes breadcrumb update before sending', () async {
      final fixture = _Fixture();
      final worker = fixture.getSut();
      await worker.start();

      final payload = await fixture.expectPendingRequest(
        worker.addBreadcrumb(Breadcrumb(
          message: 'crumb',
          data: {'value': _UnserializableValue()},
        )),
      );

      expect((payload as dynamic).breadcrumb['data'], {
        'value': 'normalized-value',
      });
    });

    test('sends breadcrumb clear request and awaits response', () async {
      final fixture = _Fixture();
      final worker = fixture.getSut();
      await worker.start();

      final payload = await fixture.expectPendingRequest(
        worker.clearBreadcrumbs(),
      );

      expect(payload.runtimeType.toString(), '_ClearBreadcrumbsRequest');
    });

    test('sends user update and awaits response', () async {
      final fixture = _Fixture();
      final worker = fixture.getSut();
      await worker.start();

      final payload = await fixture.expectPendingRequest(
        worker.setUser(SentryUser(id: 'fixture-user')),
      );

      expect((payload as dynamic).user['id'], 'fixture-user');
    });

    test('normalizes user update before sending', () async {
      final fixture = _Fixture();
      final worker = fixture.getSut();
      await worker.start();

      final payload = await fixture.expectPendingRequest(
        worker.setUser(SentryUser(
          id: 'fixture-user',
          data: {'value': _UnserializableValue()},
          // ignore: deprecated_member_use
          extras: {'extra': _UnserializableValue()},
        )),
      );

      final user = (payload as dynamic).user as Map;
      expect(user['data'], {
        'value': 'normalized-value',
      });
      expect(user['extras'], {
        'extra': 'normalized-value',
      });
    });

    test('sends context update and awaits response', () async {
      final fixture = _Fixture();
      final worker = fixture.getSut();
      await worker.start();

      final payload = await fixture.expectPendingRequest(
        worker.setContexts('fixture-key', <dynamic, dynamic>{
          'nested': <dynamic, dynamic>{'value': true}
        }),
      );

      expect((payload as dynamic).key, 'fixture-key');
      expect((payload as dynamic).value, {
        'nested': {'value': true}
      });
    });

    test('sends context remove request and awaits response', () async {
      final fixture = _Fixture();
      final worker = fixture.getSut();
      await worker.start();

      final payload = await fixture.expectPendingRequest(
        worker.removeContexts('fixture-key'),
      );

      expect((payload as dynamic).key, 'fixture-key');
    });
  });
}

class _Fixture {
  final options = SentryFlutterOptions()
    ..debug = true
    ..diagnosticLevel = SentryLevel.debug;

  final inboxes = <ReceivePort>[];
  final responsePorts = <SendPort>[];

  AndroidCoreWorker getSut() => AndroidCoreWorker(options, spawn: _fakeSpawn);

  Future<(int, Object?)> get nextRequest async {
    final request = await inboxes.last.first as (int, Object?);
    return request;
  }

  void respond(int id, Object? response) {
    responsePorts.last.send((id, response));
  }

  void respondError(int id) {
    respond(id, RemoteError('worker failure', StackTrace.current.toString()));
  }

  Future<Object?> expectPendingRequest(FutureOr<void> update) async {
    final updateFuture = Future<void>.value(update);
    var completed = false;
    unawaited(updateFuture.then((_) => completed = true));

    final (id, payload) = await nextRequest;
    await pumpEventQueue();
    expect(completed, isFalse);

    respond(id, null);
    await updateFuture;
    expect(completed, isTrue);
    return payload;
  }

  Future<Worker> _fakeSpawn(WorkerConfig config, WorkerEntry entry) async {
    final inbox = ReceivePort();
    inboxes.add(inbox);
    addTearDown(inbox.close);

    final replies = ReceivePort();
    responsePorts.add(replies.sendPort);
    addTearDown(replies.close);

    return Worker(inbox.sendPort, replies);
  }
}

class _UnserializableValue {
  @override
  String toString() => 'normalized-value';
}
