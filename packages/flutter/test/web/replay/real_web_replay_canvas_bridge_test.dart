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

    // The Replay integration blocks every other canvas via
    // [webReplayBlockSelector], which excludes this id.
    test('gives the shadow canvas the id the block selector excludes', () {
      fixture.sut.start();

      expect(fixture.shadowCanvas!.id, webReplayShadowCanvasId);
      expect(webReplayBlockSelector, contains('#$webReplayShadowCanvasId'));
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
  });

  group('feedFrame', () {
    test('snapshots the shadow canvas without waiting for animation frame', () {
      fixture.sut.start();
      fixture.sut.updatePosition(const ui.Rect.fromLTWH(0, 0, 4, 4), 1);

      fixture.sut.feedFrame(_solid(4, 4, red: 255), 4, 4);

      expect(fixture.snapshots, hasLength(1));
      expect(fixture.snapshots.single.canvas, fixture.shadowCanvas);
      expect(fixture.snapshots.single.skipRequestAnimationFrame, isTrue);
    });

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
  late final RealWebReplayCanvasBridge sut;

  _Fixture() {
    final integration = _createFakeIntegration(snapshots);
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
WebReplayCanvasIntegration _createFakeIntegration(List<_Snapshot> snapshots) {
  final integration = JSObject();
  integration['snapshot'] = ((web.HTMLCanvasElement canvas, JSObject? options) {
    final skip = options?['skipRequestAnimationFrame'];
    snapshots.add(
        _Snapshot(canvas, skip.isA<JSBoolean>() && (skip as JSBoolean).toDart));
  }).toJS;
  return integration as WebReplayCanvasIntegration;
}
