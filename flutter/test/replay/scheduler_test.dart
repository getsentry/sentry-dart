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
    await fixture.sut.stop();
    await fixture.drawFrame();
    expect(fixture.calls, 2);
  });

  test('triggers after a restart', () async {
    var fixture = _Fixture();
    fixture.sut.start();

    expect(fixture.calls, 0);
    await fixture.drawFrame();
    expect(fixture.calls, 1);
    await fixture.sut.stop();
    await fixture.drawFrame();
    expect(fixture.calls, 1);
    fixture.sut.start();
    await fixture.drawFrame();
    expect(fixture.calls, 2);
  });
}

class _Fixture {
  var calls = 0;
  late final Scheduler sut;
  FrameCallback? registeredCallback;
  var _frames = 0;

  _Fixture() {
    sut = Scheduler(
      const Duration(milliseconds: 1),
      (_) async => calls++,
      (FrameCallback callback, {String debugLabel = 'callback'}) {
        registeredCallback = callback;
      },
    );
  }

  factory _Fixture.started() {
    return _Fixture()..sut.start();
  }

  Future<void> drawFrame() async {
    await Future.delayed(const Duration(milliseconds: 8), () {});
    _frames++;
    registeredCallback!(Duration(milliseconds: _frames));
    registeredCallback = null;
  }
}
