import 'dart:async';

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
}

class _Fixture {
  var calls = 0;
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
