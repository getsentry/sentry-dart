import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/replay/scheduler.dart';

void main() {
  group('$Scheduler', () {
    test('does not trigger callback between frames', () {
      var fixture = _Fixture.started();

      expect(fixture.calls, 0);
      sleep(const Duration(milliseconds: 100));
      expect(fixture.calls, 0);
    });

    test('triggers callback after a frame', () {
      var fixture = _Fixture();
      fixture.sut.start();

      expect(fixture.calls, 0);
      fixture.drawFrame();
      expect(fixture.calls, 1);
      fixture.drawFrame();
      fixture.drawFrame();
      fixture.drawFrame();
      expect(fixture.calls, 4);
    });

    test('does not trigger when stopped', () {
      var fixture = _Fixture();
      fixture.sut.start();

      expect(fixture.calls, 0);
      fixture.drawFrame();
      expect(fixture.calls, 1);
      fixture.drawFrame();
      fixture.sut.stop();
      fixture.drawFrame();
      expect(fixture.calls, 2);
    });

    test('triggers after a restart', () {
      var fixture = _Fixture();
      fixture.sut.start();

      expect(fixture.calls, 0);
      fixture.drawFrame();
      expect(fixture.calls, 1);
      fixture.sut.stop();
      fixture.drawFrame();
      expect(fixture.calls, 1);
      fixture.sut.start();
      fixture.drawFrame();
      expect(fixture.calls, 2);
    });
  });
}

class _Fixture {
  var calls = 0;
  late final Scheduler sut;
  late FrameCallback registeredCallback;
  var _frames = 0;

  _Fixture() {
    sut = Scheduler.withCustomFrameTiming(
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

  void drawFrame() {
    _frames++;
    registeredCallback(Duration(milliseconds: _frames));
  }
}
