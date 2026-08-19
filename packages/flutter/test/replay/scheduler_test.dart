import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/replay/scheduler.dart';

void main() {
  test('does not trigger callback between frames', () async {
    var fixture = _Fixture.started();

    expect(fixture.calls, 0);
    await Future.delayed(const Duration(milliseconds: 100), () {});
    expect(fixture.calls, 0);
  });

  test('triggers callback after a frame', () async {
    var fixture = _Fixture();
    fixture.sut.start();

    expect(fixture.calls, 0);
    await fixture.drawFrame();
    expect(fixture.calls, 1);
    await fixture.drawFrame();
    await fixture.drawFrame();
    await fixture.drawFrame();
    expect(fixture.calls, 4);
  });

  test('does not trigger when stopped', () async {
    var fixture = _Fixture();
    fixture.sut.start();

    expect(fixture.calls, 0);
    await fixture.drawFrame();
    expect(fixture.calls, 1);
    await fixture.drawFrame();
    expect(fixture.calls, 2);
    await fixture.sut.stop();
    await fixture.drawFrame(awaitCallback: false);
    expect(fixture.calls, 2);
  });

  test('triggers after a restart', () async {
    var fixture = _Fixture();
    fixture.sut.start();

    expect(fixture.calls, 0);
    await fixture.drawFrame();
    expect(fixture.calls, 1);
    await fixture.sut.stop();
    await fixture.drawFrame(awaitCallback: false);
    expect(fixture.calls, 1);
    fixture.sut.start();
    await fixture.drawFrame();
    expect(fixture.calls, 2);
  });

  test('does not trigger until previous call finished', () async {
    final guard = Completer<void>();
    var fixture = _Fixture((_) async => guard.future);

    fixture.sut.start();

    expect(fixture.calls, 0);
    await fixture.drawFrame();
    expect(fixture.calls, 1);
    await fixture.drawFrame(awaitCallback: false);
    expect(fixture.calls, 1);

    guard.complete();
    await fixture.drawFrame();
    expect(fixture.calls, 2);
  });

  test('stop() awaits an in-flight callback before returning', () async {
    final guard = Completer<void>();
    var fixture = _Fixture((_) => guard.future);
    fixture.sut.start();

    await fixture.drawFrame(awaitCallback: false);
    expect(fixture.calls, 1);

    var stopped = false;
    final stopFuture = fixture.sut.stop().then((_) => stopped = true);

    // The scheduler's internal timer (1ms interval) elapses well within
    // this delay, but the capture itself is still pending on `guard`.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(stopped, isFalse,
        reason: 'stop() must not return before the in-flight '
            'callback completes');

    guard.complete();
    await stopFuture;
    expect(stopped, isTrue);
  });

  test('stop() times out and returns if the callback never completes', () {
    fakeAsync((async) {
      final guard = Completer<void>();
      final fixture = _Fixture((_) => guard.future);

      late FrameCallback callback;
      fixture.registeredCallback.future.then((cb) => callback = cb);
      fixture.sut.start();
      async.flushMicrotasks();
      callback(Duration.zero);

      var stopped = false;
      unawaited(fixture.sut.stop().then((_) {
        stopped = true;
      }));
      async.elapse(const Duration(milliseconds: 1));

      async.elapse(const Duration(milliseconds: 1999));
      expect(stopped, isFalse,
          reason: 'stop() must wait for the in-flight callback up to the '
              'timeout');

      async.elapse(const Duration(milliseconds: 1));
      expect(stopped, isTrue);
    });
  });

  test(
      'start() resumes capturing after stop() times out on a stalled '
      'callback', () {
    fakeAsync((async) {
      final guard = Completer<void>();
      final fixture = _Fixture((_) => guard.future);

      late FrameCallback callback;
      fixture.registeredCallback.future.then((cb) => callback = cb);
      fixture.sut.start();
      async.flushMicrotasks();
      callback(Duration.zero);
      expect(fixture.calls, 1);

      var stopped = false;
      unawaited(fixture.sut.stop().then((_) {
        stopped = true;
      }));
      // +1ms for the pending scheduling timer, +2s for the stop() timeout,
      // which only starts counting once that first await resolves.
      async.elapse(const Duration(seconds: 2, milliseconds: 1));
      expect(stopped, isTrue);

      // The stalled callback's future from before the timeout never
      // completes. If stop() left a reference to it behind, start() would
      // wait on it forever instead of registering a new frame callback.
      fixture.registeredCallback = Completer<FrameCallback>();
      late FrameCallback secondCallback;
      fixture.registeredCallback.future.then((cb) => secondCallback = cb);
      fixture.sut.start();
      async.flushMicrotasks();

      secondCallback(const Duration(milliseconds: 1));
      expect(fixture.calls, 2);
    });
  });

  test(
      'a stalled callback that completes after stop() times out does not '
      'schedule an extra frame callback on restart', () {
    fakeAsync((async) {
      final guard = Completer<void>();
      final fixture = _Fixture((_) => guard.future);

      late FrameCallback callback;
      fixture.registeredCallback.future.then((cb) => callback = cb);
      fixture.sut.start();
      async.flushMicrotasks();
      callback(Duration.zero);
      expect(fixture.postFrameCallbackRegistrations, 1);

      // Let the scheduling timer elapse so _runAfterNextFrame() attaches its
      // whenComplete() listener to the still-stalled callback future.
      async.elapse(const Duration(milliseconds: 1));

      unawaited(fixture.sut.stop());
      async.elapse(const Duration(seconds: 2, milliseconds: 1));

      // Restart before the stalled future ever resolves.
      fixture.registeredCallback = Completer<FrameCallback>();
      fixture.sut.start();
      async.flushMicrotasks();
      expect(fixture.postFrameCallbackRegistrations, 2,
          reason: 'start() must register exactly one new frame callback');

      // The old, abandoned callback finally completes. Its stale listener
      // must not register a second, unwanted frame callback on top of the
      // one start() just registered.
      guard.complete();
      async.flushMicrotasks();
      expect(fixture.postFrameCallbackRegistrations, 2,
          reason: 'a stale callback future must not re-trigger scheduling '
              'after stop() has moved on');
    });
  });
}

class _Fixture {
  var calls = 0;
  var postFrameCallbackRegistrations = 0;
  late final Scheduler sut;
  var registeredCallback = Completer<FrameCallback>();
  var _frames = 0;

  _Fixture([SchedulerCallback? callback]) {
    sut = Scheduler(
      const Duration(milliseconds: 1),
      (timestamp) async {
        calls++;
        await callback?.call(timestamp);
      },
      _addPostFrameCallbackMock,
    );
  }

  void _addPostFrameCallbackMock(FrameCallback callback,
      {String debugLabel = 'callback'}) {
    postFrameCallbackRegistrations++;
    if (!registeredCallback.isCompleted) {
      registeredCallback.complete(callback);
    }
  }

  factory _Fixture.started() {
    return _Fixture()..sut.start();
  }

  Future<void> drawFrame({bool awaitCallback = true}) async {
    registeredCallback = Completer<FrameCallback>();
    final timestamp = Duration(milliseconds: ++_frames);
    final future = registeredCallback.future.then((fn) => fn(timestamp));
    if (awaitCallback) {
      return future;
    } else {
      return future.timeout(const Duration(milliseconds: 200),
          onTimeout: () {});
    }
  }
}
