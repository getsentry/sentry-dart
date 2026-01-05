@TestOn('vm')
// ignore_for_file: invalid_use_of_internal_member
library;

import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/java/android_envelope_sender.dart';
import 'package:sentry_flutter/src/isolate/isolate_worker.dart';

void main() {
  group('AndroidEnvelopeSender host behavior', () {
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

      final sender = AndroidEnvelopeSender(options);
      sender.captureEnvelope(Uint8List.fromList([1, 2, 3]), false);

      expect(
        logs.any((e) =>
            e.$1 == SentryLevel.info &&
            e.$2.contains(
                'captureEnvelope called before worker started: sending envelope in main isolate instead')),
        isTrue,
      );
    });

    test('close is a no-op when not started', () {
      final options = SentryFlutterOptions();
      final sender = AndroidEnvelopeSender(options);
      expect(() => sender.close(), returnsNormally);
      expect(() => sender.close(), returnsNormally);
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

      final sender = AndroidEnvelopeSender(options, spawn: fakeSpawn);

      await sender.start();
      await sender.start();
      expect(spawnCount, 1);

      sender.close();
      spawnCount = 0;

      await sender.start();
      expect(spawnCount, 0);

      // Close twice should be safe.
      expect(() => sender.close(), returnsNormally);
      expect(() => sender.close(), returnsNormally);
    });

    test('delivers tuple to worker after start', () async {
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

      final sender = AndroidEnvelopeSender(options, spawn: fakeSpawn);
      await sender.start();

      final payload = Uint8List.fromList([4, 5, 6]);
      sender.captureEnvelope(payload, true);

      final msg = await inboxes.last.first;
      expect(msg, isA<(TransferableTypedData, bool)>());
      final (transferable, containsUnhandled) =
          msg as (TransferableTypedData, bool);
      expect(containsUnhandled, true);
      final data = transferable.materialize().asUint8List();
      expect(data, [4, 5, 6]);

      sender.close();
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

      final sender = AndroidEnvelopeSender(options, spawn: fakeSpawn);
      await sender.start();

      expect(seenConfig, isNotNull);
      expect(seenConfig!.debugName, 'SentryAndroidEnvelopeSender');
      expect(seenConfig!.debug, options.debug);
      expect(seenConfig!.diagnosticLevel, options.diagnosticLevel);

      sender.close();
    });

    test('sends are delivered sequentially with flags', () async {
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

      final sender = AndroidEnvelopeSender(options, spawn: fakeSpawn);
      await sender.start();

      sender.captureEnvelope(Uint8List.fromList([10]), true);
      sender.captureEnvelope(Uint8List.fromList([11]), false);

      final inbox = inboxes.last;
      final msgs = await inbox.take(2).toList();
      final msg1 = msgs[0];
      final msg2 = msgs[1];

      expect(msg1, isA<(TransferableTypedData, bool)>());
      expect(msg2, isA<(TransferableTypedData, bool)>());

      final (t1, f1) = msg1 as (TransferableTypedData, bool);
      final (t2, f2) = msg2 as (TransferableTypedData, bool);
      expect(f1, true);
      expect(f2, false);
      final data1 = t1.materialize().asUint8List();
      final data2 = t2.materialize().asUint8List();
      expect(data1, [10]);
      expect(data2, [11]);

      sender.close();
    });
  });
}
