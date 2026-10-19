@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/web/replay/real_web_replay_canvas_bridge.dart';
import 'package:sentry_flutter/src/web/replay/web_replay_canvas_bridge.dart';
import 'package:web/web.dart' as web;

void main() {
  group('$RealWebReplayCanvasBridge', () {
    late _Fixture fixture;

    setUp(() {
      fixture = _Fixture();
    });

    tearDown(() {
      fixture.dispose();
    });

    group('start', () {
      test('adds a shadow canvas behind the app', () {
        fixture.sut.start();

        final shadow = fixture.shadowCanvas;
        expect(shadow, isNotNull);
        expect(shadow!.style.position, 'fixed');
        expect(shadow.style.zIndex, '-1');
      });

      // The Replay integration blocks every canvas matching
      // [webReplayBlockSelector], which must spare this one.
      test('gives the shadow canvas an id the block selector spares', () {
        fixture.sut.start();
        final appCanvas = web.document.createElement('canvas');

        expect(fixture.shadowCanvas!.id, 'sentry-flutter-replay-canvas');
        expect(fixture.shadowCanvas!.matches(webReplayBlockSelector), isFalse);
        expect(appCanvas.matches(webReplayBlockSelector), isTrue);
      });

      test('is idempotent', () {
        fixture.sut.start();
        fixture.sut.start();

        expect(fixture.shadowCanvases, hasLength(1));
      });
    });

    group('updatePosition', () {
      test('sizes the shadow canvas in css pixels', () {
        fixture.sut.start();

        fixture.sut.updatePosition(const ui.Rect.fromLTWH(10, 20, 300, 200), 1);

        final style = fixture.shadowCanvas!.style;
        expect(style.left, '10px');
        expect(style.top, '20px');
        expect(style.width, '300px');
        expect(style.height, '200px');
      });

      // The replayer falls back to the backing buffer size, so it must always
      // equal css size * devicePixelRatio (see #2897).
      test('sizes the backing buffer as css size times devicePixelRatio', () {
        fixture.sut.start();

        fixture.sut.updatePosition(const ui.Rect.fromLTWH(0, 0, 300, 200), 2);

        expect(fixture.shadowCanvas!.width, 600);
        expect(fixture.shadowCanvas!.height, 400);
      });

      test('does nothing when not started', () {
        fixture.sut.updatePosition(const ui.Rect.fromLTWH(0, 0, 300, 200), 2);

        expect(fixture.shadowCanvas, isNull);
      });

      // Sentry's replay player clones a canvas once, on its first recorded
      // draw, and keeps drawing into that clone -- later width/height changes
      // never reach it. A new element gets a fresh clone at the new size.
      test('replaces a snapshotted shadow canvas when its size changes', () {
        fixture.sut.start();
        fixture.sut.updatePosition(const ui.Rect.fromLTWH(0, 0, 4, 4), 1);
        fixture.sut.feedFrame(_solid(4, 4, red: 255), 4, 4);
        final previous = fixture.shadowCanvas!;

        fixture.sut.updatePosition(const ui.Rect.fromLTWH(0, 0, 8, 4), 1);

        final current = fixture.shadowCanvas!;
        expect(current, isNot(same(previous)));
        expect(previous.isConnected, isFalse);
        expect(current.id, 'sentry-flutter-replay-canvas');
        expect(current.style.position, 'fixed');
        expect(current.style.zIndex, '-1');
        expect(current.style.width, '8px');
        expect(current.width, 8);
        expect(current.height, 4);
      });

      test('keeps the shadow canvas when only its position changes', () {
        fixture.sut.start();
        fixture.sut.updatePosition(const ui.Rect.fromLTWH(0, 0, 4, 4), 1);
        fixture.sut.feedFrame(_solid(4, 4, red: 255), 4, 4);
        final previous = fixture.shadowCanvas!;

        fixture.sut.updatePosition(const ui.Rect.fromLTWH(5, 5, 4, 4), 1);

        expect(fixture.shadowCanvas, same(previous));
        expect(previous.style.left, '5px');
      });
    });

    group('feedFrame', () {
      test(
        'snapshots the shadow canvas without waiting for animation frame',
        () {
          fixture.sut.start();
          fixture.sut.updatePosition(const ui.Rect.fromLTWH(0, 0, 4, 4), 1);

          fixture.sut.feedFrame(_solid(4, 4, red: 255), 4, 4);

          expect(fixture.snapshots, hasLength(1));
          expect(fixture.snapshots.single.canvas, fixture.shadowCanvas);
          expect(fixture.snapshots.single.skipRequestAnimationFrame, isTrue);
        },
      );

      test('draws the frame onto the shadow canvas', () {
        fixture.sut.start();
        fixture.sut.updatePosition(const ui.Rect.fromLTWH(0, 0, 4, 4), 1);

        fixture.sut.feedFrame(_solid(4, 4, red: 255), 4, 4);

        final pixel = fixture.pixelAt(fixture.shadowCanvas!, 1, 1);
        expect(pixel, [255, 0, 0, 255]);
      });

      test('scales a smaller frame up to the shadow canvas size', () {
        fixture.sut.start();
        fixture.sut.updatePosition(const ui.Rect.fromLTWH(0, 0, 8, 8), 1);

        fixture.sut.feedFrame(_solid(4, 4, red: 255), 4, 4);

        final shadow = fixture.shadowCanvas!;
        expect(shadow.width, 8);
        expect(shadow.height, 8);
        expect(fixture.pixelAt(shadow, 7, 7), [255, 0, 0, 255]);
      });

      test('does nothing when not started', () {
        fixture.sut.feedFrame(_solid(4, 4, red: 255), 4, 4);

        expect(fixture.snapshots, isEmpty);
      });

      // rrweb only snapshots canvases it has registered, which happens in its
      // MutationObserver callback -- after the task that added the element.
      test('snapshots a replaced shadow canvas on the next task', () async {
        fixture.sut.start();
        fixture.sut.updatePosition(const ui.Rect.fromLTWH(0, 0, 4, 4), 1);
        fixture.sut.feedFrame(_solid(4, 4, red: 255), 4, 4);
        fixture.sut.updatePosition(const ui.Rect.fromLTWH(0, 0, 8, 4), 1);

        fixture.sut.feedFrame(_solid(8, 4, red: 255), 8, 4);

        expect(fixture.snapshots, hasLength(1));
        await Future<void>.delayed(Duration.zero);
        expect(fixture.snapshots, hasLength(2));
        expect(fixture.snapshots.last.canvas, fixture.shadowCanvas);
      });

      // The deferred snapshot runs outside the recorder's error handling.
      test('contains a throwing deferred snapshot', () async {
        fixture.sut.start();
        fixture.sut.updatePosition(const ui.Rect.fromLTWH(0, 0, 4, 4), 1);
        fixture.sut.feedFrame(_solid(4, 4, red: 255), 4, 4);
        fixture.sut.updatePosition(const ui.Rect.fromLTWH(0, 0, 8, 4), 1);
        fixture.sut.feedFrame(_solid(8, 4, red: 255), 8, 4);
        fixture.throwOnSnapshot = true;

        await Future<void>.delayed(Duration.zero);

        expect(fixture.snapshots, hasLength(1));
      });

      test('drops a deferred snapshot when stopped before it runs', () async {
        fixture.sut.start();
        fixture.sut.updatePosition(const ui.Rect.fromLTWH(0, 0, 4, 4), 1);
        fixture.sut.feedFrame(_solid(4, 4, red: 255), 4, 4);
        fixture.sut.updatePosition(const ui.Rect.fromLTWH(0, 0, 8, 4), 1);
        fixture.sut.feedFrame(_solid(8, 4, red: 255), 8, 4);

        fixture.sut.stop();
        await Future<void>.delayed(Duration.zero);

        expect(fixture.snapshots, hasLength(1));
      });
    });

    group('stop', () {
      test('removes the shadow canvas', () {
        fixture.sut.start();

        fixture.sut.stop();

        expect(fixture.shadowCanvas, isNull);
      });

      test('can be started again', () {
        fixture.sut.start();
        fixture.sut.stop();

        fixture.sut.start();

        expect(fixture.shadowCanvases, hasLength(1));
      });
    });
  });
}

Uint8List _solid(int width, int height, {int red = 0}) {
  final data = Uint8List(width * height * 4);
  for (var i = 0; i < data.length; i += 4) {
    data[i] = red;
    data[i + 3] = 255;
  }
  return data;
}

class _Snapshot {
  _Snapshot(this.canvas, this.skipRequestAnimationFrame);
  final web.HTMLCanvasElement canvas;
  final bool skipRequestAnimationFrame;
}

class _Fixture {
  final snapshots = <_Snapshot>[];
  var throwOnSnapshot = false;
  late final RealWebReplayCanvasBridge sut;

  _Fixture() {
    final integration = _createFakeIntegration(
      snapshots,
      () => throwOnSnapshot,
    );
    sut = RealWebReplayCanvasBridge(integration);
  }

  List<web.HTMLCanvasElement> get shadowCanvases {
    final result = <web.HTMLCanvasElement>[];
    final all = web.document.querySelectorAll('canvas');
    for (var i = 0; i < all.length; i++) {
      result.add(all.item(i) as web.HTMLCanvasElement);
    }
    return result;
  }

  web.HTMLCanvasElement? get shadowCanvas {
    final canvases = shadowCanvases;
    return canvases.isEmpty ? null : canvases.single;
  }

  List<int> pixelAt(web.HTMLCanvasElement canvas, int x, int y) {
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    final data = ctx.getImageData(x, y, 1, 1).data.toDart;
    return data.toList();
  }

  void dispose() {
    sut.stop();
  }
}

/// A stand-in for the JS SDK's canvas integration that records `snapshot`
/// calls.
WebReplayCanvasIntegration _createFakeIntegration(
  List<_Snapshot> snapshots,
  bool Function() shouldThrow,
) {
  final integration = JSObject();
  integration['snapshot'] = ((web.HTMLCanvasElement canvas, JSObject? options) {
    if (shouldThrow()) throw StateError('snapshot failed');
    final skip = options?['skipRequestAnimationFrame'];
    snapshots.add(
      _Snapshot(canvas, skip.isA<JSBoolean>() && (skip as JSBoolean).toDart),
    );
  }).toJS;
  return integration as WebReplayCanvasIntegration;
}
