@TestOn('vm')
// ignore_for_file: invalid_use_of_internal_member
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/cocoa/cocoa_envelope_sender.dart';
import 'package:sentry_flutter/src/isolate/isolate_worker.dart';

void main() {
  group('CocoaEnvelopeSender host behavior', () {
    test('warns and drops when not started', () {
      final options = SentryFlutterOptions();
      options.debug = true;
      options.diagnosticLevel = SentryLevel.debug;
      final logs = <(SentryLevel, String)>[];
      options.log = (level, message, {logger, exception, stackTrace}) {
        logs.add((level, message));
      };

      final sender = CocoaEnvelopeSender(options);
      sender.captureEnvelope(Uint8List.fromList([1, 2, 3]));

      expect(
        logs.any((e) =>
            e.$1 == SentryLevel.warning &&
            e.$2.contains('captureEnvelope called before start; dropping')),
        isTrue,
      );
    });

    test('close is a no-op when not started', () {
      final options = SentryFlutterOptions();
      final sender = CocoaEnvelopeSender(options);
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
        late final StreamSubscription<dynamic> sub;
        sub = inbox.listen((msg) async {
          if (msg == '_shutdown_') {
            await sub.cancel();
            inbox.close();
          }
        });
        return Worker(inbox.sendPort);
      }

      final sender = CocoaEnvelopeSender(options, spawn: fakeSpawn);

      await sender.start();
      await sender.start();
      expect(spawnCount, 1);

      sender.close();
      spawnCount = 0;

      await sender.start();
      expect(spawnCount, 1);

      // Close twice should be safe.
      expect(() => sender.close(), returnsNormally);
      expect(() => sender.close(), returnsNormally);
    });

    test('warns and drops after close', () async {
      final options = SentryFlutterOptions();
      options.debug = true;
      options.diagnosticLevel = SentryLevel.debug;
      final logs = <(SentryLevel, String)>[];
      options.log = (level, message, {logger, exception, stackTrace}) {
        logs.add((level, message));
      };

      final sender = CocoaEnvelopeSender(options);
      await sender.start();
      sender.close();

      sender.captureEnvelope(Uint8List.fromList([9]));

      expect(
        logs.any((e) =>
            e.$1 == SentryLevel.warning &&
            e.$2.contains('captureEnvelope called before start; dropping')),
        isTrue,
      );
    });

    test('sends are delivered sequentially', () async {
      final options = SentryFlutterOptions();
      options.debug = true;
      options.diagnosticLevel = SentryLevel.debug;

      final inboxes = <ReceivePort>[];
      Future<Worker> fakeSpawn(WorkerConfig config, WorkerEntry entry) async {
        final inbox = ReceivePort();
        inboxes.add(inbox);
        addTearDown(() => inbox.close());
        return Worker(inbox.sendPort);
      }

      final sender = CocoaEnvelopeSender(options, spawn: fakeSpawn);
      await sender.start();

      sender.captureEnvelope(Uint8List.fromList([10]));
      sender.captureEnvelope(Uint8List.fromList([11]));

      final inbox = inboxes.last;
      final msgs = await inbox.take(2).toList();
      final msg1 = msgs[0];
      final msg2 = msgs[1];

      expect(msg1, isA<TransferableTypedData>());
      expect(msg2, isA<TransferableTypedData>());

      final data1 = (msg1 as TransferableTypedData).materialize().asUint8List();
      final data2 = (msg2 as TransferableTypedData).materialize().asUint8List();
      expect(data1, [10]);
      expect(data2, [11]);

      sender.close();
    });

    test('delivers to worker after start', () async {
      final options = SentryFlutterOptions();
      options.debug = true;
      options.diagnosticLevel = SentryLevel.debug;

      final inboxes = <ReceivePort>[];
      Future<Worker> fakeSpawn(WorkerConfig config, WorkerEntry entry) async {
        final inbox = ReceivePort();
        inboxes.add(inbox);
        addTearDown(() => inbox.close());
        return Worker(inbox.sendPort);
      }

      final sender = CocoaEnvelopeSender(options, spawn: fakeSpawn);
      await sender.start();

      final payload = Uint8List.fromList([1, 2, 3]);
      sender.captureEnvelope(payload);

      final msg = await inboxes.last.first;
      expect(msg, isA<TransferableTypedData>());
      final data = (msg as TransferableTypedData).materialize().asUint8List();
      expect(data, [1, 2, 3]);

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
        return Worker(inbox.sendPort);
      }

      final sender = CocoaEnvelopeSender(options, spawn: fakeSpawn);
      await sender.start();

      expect(seenConfig, isNotNull);
      expect(seenConfig!.debugName, 'SentryCocoaEnvelopeSender');
      expect(seenConfig!.debug, options.debug);
      expect(seenConfig!.diagnosticLevel, options.diagnosticLevel);

      sender.close();
    });
  });
}
