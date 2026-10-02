import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:meta/meta.dart';

/// DOM id of the shadow canvas.
@internal
const webReplayShadowCanvasId = 'sentry-flutter-replay-canvas';

/// Selector for the JS Replay integration's `block` option: blocks every
/// `<canvas>` (Flutter's real, sensitive content -- `blockAllMedia` doesn't
/// cover canvas) except the shadow canvas, which carries the masked frames.
/// A selector rather than tagging canvases that exist at start, because
/// Flutter's canvases live in `flt-glass-pane`'s shadow DOM and may be
/// created later (e.g. for platform views).
@internal
const webReplayBlockSelector = 'canvas:not(#$webReplayShadowCanvasId)';

/// Owns the hidden "shadow canvas" that stands in for Flutter's real,
/// blocked canvas in Flutter Web session replay recordings (#2897).
///
/// The shadow canvas is positioned exactly over the real content's on-screen
/// rect but stacked behind it (`z-index: -1`), so live viewers never see it
/// -- Flutter's own canvas paints over it at the same position -- while
/// rrweb's manual canvas-snapshot API still captures its content for the
/// recording. Frames fed to it have already been captured and masked in
/// Dart; an implementation of this interface only needs to get already-
/// masked pixels onto a canvas element and tell rrweb to snapshot it.
///
/// Deliberately free of any `dart:js_interop`/`package:web` types (that
/// library isn't importable outside web at all -- see the conditional
/// export in `sentry_js_binding.dart`) so [SentryWebReplayRecorder] can be
/// unit-tested on the VM against a fake, with the real DOM-touching
/// implementation ([RealWebReplayCanvasBridge]) exercised only by an
/// integration test.
@internal
abstract class WebReplayCanvasBridge {
  /// Creates the shadow canvas ([webReplayShadowCanvasId]).
  void start();

  /// Positions the shadow canvas over [rect] (logical/CSS pixels, matching
  /// the real content's actual on-screen position) and sizes its backing
  /// buffer to `rect.size * devicePixelRatio` -- always, regardless of
  /// capture scale.
  ///
  /// Confirmed (#2897): canvas-mutation replay ignores a separately-applied
  /// CSS display size and falls back to rendering the canvas at its own
  /// backing-buffer pixel dimensions when the two diverge. Resolution
  /// scaling therefore must not shrink this canvas -- it happens on the
  /// source frame fed to [feedFrame] instead, which gets scaled up onto this
  /// canvas regardless of its own fixed size.
  void updatePosition(ui.Rect rect, double devicePixelRatio);

  /// Feeds one already-captured, already-masked frame.
  ///
  /// [rgba] is straight-alpha, row-major RGBA bytes at [width]x[height] --
  /// may be smaller than the shadow canvas's own backing buffer if
  /// resolution scaling is active; implementations scale it up to fill the
  /// canvas either way.
  void feedFrame(Uint8List rgba, int width, int height);

  /// Removes the shadow canvas and unblocks whatever [start] blocked.
  void stop();
}
