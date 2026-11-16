@TestOn('vm')
library;

import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/isolate/isolate_worker.dart';
import 'package:sentry_flutter/src/native/c/sentry_native_worker.dart';

import '../../mocks.dart';

void main() {
  late SentryFlutterOptions options;
  late List<String> log;
  late List<_FakeWorker> fakes;
  late SpawnWorkerFn spawn;

  setUp(() {
    options = SentryFlutterOptions(dsn: fakeDsn)
      // ignore: invalid_use_of_internal_member
      ..automatedTestMode = true;
    log = [];
    fakes = [];
    spawn = SentryNativeWorker.spawnWorkerFn;
    SentryNativeWorker.spawnWorkerFn = (_, _) async =>
        fakes.firstWhere((fake) => !fake.spawned).spawn();
  });

  tearDown(() {
    SentryNativeWorker.spawnWorkerFn = spawn;
    SentryNativeWorker.resetPreviousClose();
    for (final fake in fakes) {
      fake.dispose();
    }
  });

  _FakeWorker fake(String name, {Object? Function(String kind)? answer}) {
    final worker = _FakeWorker(name, log, answer ?? _succeed);
    fakes.add(worker);
    return worker;
  }

  SentryNativeWorker create() =>
      SentryNativeWorker(options, () => Pointer.fromAddress(1));

  test('init returns at once and later calls run after it, in order', () async {
    fake('w');
    final sut = create();

    sut.start();
    final tag = sut.setTag('fixture-key', 'fixture-value');
    final breadcrumb = sut.addBreadcrumb(Breadcrumb(message: 'fixture'));
    await sut.initialized;
    await tag;
    await breadcrumb;

    expect(log, ['w:Load', 'w:Init', 'w:SetTag', 'w:AddBreadcrumb']);
  });

  test('calls made before init are queued without waiting', () async {
    fake('w');
    final sut = create();

    expect(sut.setTag('fixture-key', 'fixture-value'), isNull);
    sut.start();
    await sut.initialized;
    await pumpEventQueue();

    expect(log, ['w:Load', 'w:Init', 'w:SetTag']);
  });

  test('a call completes once the worker ran it', () async {
    final worker = fake('w', answer: (_) => _hold);
    final sut = create()..useWorker(worker.spawn());
    var done = false;

    final tag = Future.value(
      sut.setTag('fixture-key', 'fixture-value'),
    ).then((_) => done = true);
    await pumpEventQueue();
    expect(done, isFalse);
    worker.answerHeld();
    await tag;

    expect(done, isTrue);
  });

  test('closes the worker when sentry_init fails', () async {
    final worker = fake('w', answer: (kind) => kind == 'Init' ? 1 : 0);
    final sut = create();

    sut.start();

    await expectLater(sut.initialized, throwsStateError);
    expect(await sut.target, isNull);
    await worker.shutdown.future;
    expect(log, ['w:Load', 'w:Init']);
  });

  test('without auto-init, calls do not wait for an init', () async {
    options.autoInitializeNativeSdk = false;

    expect(await create().target, isNull);
  });

  test('drops calls beyond maxPendingRequests', () async {
    final max = SentryNativeWorker.maxPendingRequests;
    SentryNativeWorker.maxPendingRequests = 2;
    addTearDown(() => SentryNativeWorker.maxPendingRequests = max);
    final worker = fake('w', answer: (_) => _hold);
    final sut = create()..useWorker(worker.spawn());

    final first = sut.addBreadcrumb(Breadcrumb(message: '1'));
    final second = sut.addBreadcrumb(Breadcrumb(message: '2'));
    expect(sut.setUser(null), isNull);
    await pumpEventQueue();
    worker.answerHeld();
    await first;
    await second;
    final clear = sut.setUser(null);
    await pumpEventQueue();
    worker.answerHeld();
    await clear;

    expect(log, ['w:AddBreadcrumb', 'w:AddBreadcrumb', 'w:SetUser']);
  });

  test('close runs after earlier calls, then shuts the worker down', () async {
    final worker = fake('w');
    final sut = create()..useWorker(worker.spawn());

    unawaited(Future.value(sut.setTag('fixture-key', 'fixture-value')));
    await sut.close();
    await worker.shutdown.future;

    expect(log, ['w:SetTag', 'w:Close']);
    expect(sut.setTag('fixture-key', 'fixture-value'), isNull);
    expect(sut.close(), completes);
  });

  test('close stops waiting after closeTimeout', () {
    fakeAsync((async) {
      final worker = fake('w', answer: (_) => _hold);
      final sut = create()..useWorker(worker.spawn());
      var closed = false;

      sut.close().then((_) => closed = true);
      async.elapse(
        SentryNativeWorker.closeTimeout - const Duration(milliseconds: 1),
      );
      expect(closed, isFalse);
      async.elapse(const Duration(milliseconds: 1));

      expect(closed, isTrue);
    });
  });

  test('the next init waits for a close still running', () async {
    final first = fake('first', answer: (_) => _hold);
    fake('second');
    final previous = create()..useWorker(first.spawn());
    unawaited(previous.close());
    final sut = create();

    sut.start();
    await pumpEventQueue();
    expect(log, ['first:Close']);
    first.answerHeld();
    await sut.initialized;

    expect(log, ['first:Close', 'second:Load', 'second:Init']);
  });

  test('a close queued behind an init runs before the next init', () async {
    final first = fake('first', answer: (_) => _hold);
    fake('second');
    fake('third');
    final previous = create()..useWorker(first.spawn());
    unawaited(previous.close());
    final second = create()..start();
    unawaited(second.close());
    final third = create()..start();

    await pumpEventQueue();
    first.answerHeld();
    await third.initialized;

    expect(log, [
      'first:Close',
      'second:Load',
      'second:Init',
      'second:Close',
      'third:Load',
      'third:Init',
    ]);
  });
}

const _hold = Object();

Object? _succeed(String kind) => kind == 'Load' || kind == 'Init' ? 0 : null;

class _FakeWorker {
  _FakeWorker(this.name, this.log, this.answer) {
    inbox.listen((message) {
      if (message == '_shutdown_') {
        shutdown.complete();
        return;
      }
      final (int id, Object? payload) = message as (int, Object?);
      final kind = payload.runtimeType
          .toString()
          .replaceFirst('_', '')
          .replaceFirst('Request', '');
      log.add('$name:$kind');
      final response = answer(kind);
      if (identical(response, _hold)) {
        held.add(id);
      } else {
        responses.sendPort.send((id, response));
      }
    });
  }

  final String name;
  final List<String> log;
  final Object? Function(String kind) answer;
  final inbox = ReceivePort();
  final responses = ReceivePort();
  final shutdown = Completer<void>();
  final held = <int>[];
  bool spawned = false;

  Worker spawn() {
    spawned = true;
    return Worker(inbox.sendPort, responses);
  }

  void answerHeld() {
    for (final id in held) {
      responses.sendPort.send((id, null));
    }
    held.clear();
  }

  void dispose() {
    inbox.close();
    responses.close();
  }
}
