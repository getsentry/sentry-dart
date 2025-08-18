// ignore_for_file: uri_does_not_exist, undefined_class, undefined_function, undefined_identifier, undefined_member, unused_import, unused_field, unnecessary_import, invalid_override
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'minimal_replay.dart';

class _RecordingUiCanvas implements ui.Canvas {
  _RecordingUiCanvas(this._controller);

  final ReplayRecorderController _controller;
  final ui.Canvas _nativeCanvas = ui.Canvas(ui.PictureRecorder());

  // --- helpers to serialize args like the minimal ICanvas does ---
  List<num> _rect(ui.Rect r) => [r.left, r.top, r.right, r.bottom];
  List<num> _rrect(ui.RRect r) => [
        r.left,
        r.top,
        r.right,
        r.bottom,
        r.tlRadiusX,
        r.tlRadiusY,
        r.trRadiusX,
        r.trRadiusY,
        r.brRadiusX,
        r.brRadiusY,
        r.blRadiusX,
        r.blRadiusY,
      ];
  List<num> _offset(ui.Offset o) => [o.dx, o.dy];
  List<double> _mat4(Float64List m) => m.toList(growable: false).cast<double>();
  Map<String, dynamic> _paint(ui.Paint p) => {
        'color': p.color.value,
        'style': p.style.index,
        'strokeWidth': p.strokeWidth,
        'blendMode': p.blendMode.index,
        'isAntiAlias': p.isAntiAlias,
      };

  void _cmd(String name, List<dynamic> args) =>
      _controller.recordCommand(name, args);

  // --- State ---
  @override
  void save() {
    _cmd('save', const []);
    _nativeCanvas.save();
  }

  @override
  void restore() {
    _cmd('restore', const []);
    if (_nativeCanvas.getSaveCount() > 1) {
      _nativeCanvas.restore();
    }
  }

  @override
  void saveLayer(ui.Rect? bounds, ui.Paint paint) {
    _cmd('saveLayer', [bounds != null ? _rect(bounds) : null, _paint(paint)]);
    _nativeCanvas.saveLayer(bounds, paint);
  }

  @override
  void translate(double dx, double dy) {
    _cmd('translate', [dx, dy]);
    _nativeCanvas.translate(dx, dy);
  }

  @override
  void scale(double sx, [double? sy]) {
    _cmd('scale', [sx, sy ?? sx]);
    _nativeCanvas.scale(sx, sy);
  }

  @override
  void rotate(double radians) {
    _cmd('rotate', [radians]);
    _nativeCanvas.rotate(radians);
  }

  @override
  void transform(Float64List matrix4) {
    _cmd('transform', [_mat4(matrix4)]);
    _nativeCanvas.transform(matrix4);
  }

  // --- Clip ---
  @override
  void clipRect(ui.Rect rect,
      {ui.ClipOp clipOp = ui.ClipOp.intersect, bool doAntiAlias = true}) {
    _cmd('clipRect', [_rect(rect), clipOp.index, doAntiAlias]);
    _nativeCanvas.clipRect(rect, clipOp: clipOp, doAntiAlias: doAntiAlias);
  }

  @override
  void clipRRect(ui.RRect rrect, {bool doAntiAlias = true}) {
    _cmd('clipRRect', [_rrect(rrect), doAntiAlias]);
    _nativeCanvas.clipRRect(rrect, doAntiAlias: doAntiAlias);
  }

  @override
  void clipPath(ui.Path path, {bool doAntiAlias = true}) {
    _cmd('clipPath', [path.getBounds().toString(), doAntiAlias]);
    // Minimal: approximate by clipping bounds
    _nativeCanvas.clipRect(path.getBounds(), doAntiAlias: doAntiAlias);
  }

  // --- Draw ---
  @override
  void drawDRRect(ui.RRect outer, ui.RRect inner, ui.Paint paint) {
    _cmd('drawDRRect', [_rrect(outer), _rrect(inner), _paint(paint)]);
    _nativeCanvas.drawDRRect(outer, inner, paint);
  }

  @override
  void drawShadow(ui.Path path, ui.Color color, double elevation,
      bool transparentOccluder) {
    _cmd('drawShadow', [
      path.getBounds().toString(),
      color.value,
      elevation,
      transparentOccluder
    ]);
    _nativeCanvas.drawShadow(path, color, elevation, transparentOccluder);
  }

  @override
  void drawColor(ui.Color color, ui.BlendMode blendMode) {
    _cmd('drawColor', [color.value, blendMode.index]);
    _nativeCanvas.drawColor(color, blendMode);
  }

  @override
  void drawRect(ui.Rect rect, ui.Paint paint) {
    _cmd('drawRect', [_rect(rect), _paint(paint)]);
    _nativeCanvas.drawRect(rect, paint);
  }

  @override
  void drawRRect(ui.RRect rrect, ui.Paint paint) {
    _cmd('drawRRect', [_rrect(rrect), _paint(paint)]);
    _nativeCanvas.drawRRect(rrect, paint);
  }

  @override
  void drawCircle(ui.Offset c, double radius, ui.Paint paint) {
    _cmd('drawCircle', [_offset(c), radius, _paint(paint)]);
    _nativeCanvas.drawCircle(c, radius, paint);
  }

  @override
  void drawLine(ui.Offset p1, ui.Offset p2, ui.Paint paint) {
    _cmd('drawLine', [_offset(p1), _offset(p2), _paint(paint)]);
    _nativeCanvas.drawLine(p1, p2, paint);
  }

  @override
  void drawOval(ui.Rect rect, ui.Paint paint) {
    _cmd('drawOval', [_rect(rect), _paint(paint)]);
    _nativeCanvas.drawOval(rect, paint);
  }

  @override
  void drawPath(ui.Path path, ui.Paint paint) {
    _cmd('drawPath', [path.getBounds().toString(), _paint(paint)]);
    _nativeCanvas.drawPath(path, paint);
  }

  @override
  void drawPaint(ui.Paint paint) {
    _cmd('drawPaint', [_paint(paint)]);
    _nativeCanvas.drawPaint(paint);
  }

  @override
  void drawPoints(
      ui.PointMode pointMode, List<ui.Offset> points, ui.Paint paint) {
    _cmd('drawPoints', [
      pointMode.index,
      points.map(_offset).toList(),
      _paint(paint),
    ]);
    _nativeCanvas.drawPoints(pointMode, points, paint);
  }

  @override
  void drawImage(ui.Image image, ui.Offset p, ui.Paint paint) {
    _cmd('drawImage', [_offset(p), image.width, image.height, _paint(paint)]);
    _nativeCanvas.drawImage(image, p, paint);
  }

  @override
  void drawImageRect(ui.Image image, ui.Rect src, ui.Rect dst, ui.Paint paint) {
    _cmd('drawImageRect',
        [_rect(src), _rect(dst), image.width, image.height, _paint(paint)]);
    _nativeCanvas.drawImageRect(image, src, dst, paint);
  }

  @override
  void drawParagraph(ui.Paragraph paragraph, ui.Offset offset) {
    _cmd('drawParagraph', [_offset(offset), paragraph.width, paragraph.height]);
    _nativeCanvas.drawParagraph(paragraph, offset);
  }

  // --- Queries ---
  @override
  int getSaveCount() => _nativeCanvas.getSaveCount();
  @override
  ui.Rect getLocalClipBounds() => _nativeCanvas.getLocalClipBounds();
  @override
  ui.Rect getDestinationClipBounds() =>
      _nativeCanvas.getDestinationClipBounds();
  @override
  Float64List getTransform() => _nativeCanvas.getTransform();

  // --- Unimplemented/minimal ops ---
  @override
  void clipRSuperellipse(ui.RSuperellipse rsuperellipse,
      {bool doAntiAlias = true}) {}
  @override
  void drawArc(ui.Rect rect, double startAngle, double sweepAngle,
      bool useCenter, ui.Paint paint) {}
  @override
  void drawAtlas(
      ui.Image atlas,
      List<ui.RSTransform> transforms,
      List<ui.Rect> rects,
      List<ui.Color>? colors,
      ui.BlendMode? blendMode,
      ui.Rect? cullRect,
      ui.Paint paint) {}
  @override
  void drawImageNine(
      ui.Image image, ui.Rect center, ui.Rect dst, ui.Paint paint) {}
  @override
  void drawPicture(ui.Picture picture) {}
  @override
  void drawRSuperellipse(ui.RSuperellipse rsuperellipse, ui.Paint paint) {}
  @override
  void restoreToCount(int count) {}
  @override
  void skew(double sx, double sy) {}
  @override
  void drawRawAtlas(
      ui.Image atlas,
      Float32List rstTransforms,
      Float32List rects,
      Int32List? colors,
      ui.BlendMode? blendMode,
      ui.Rect? cullRect,
      ui.Paint paint) {}
  @override
  void drawRawPoints(
      ui.PointMode pointMode, Float32List points, ui.Paint paint) {}
  @override
  void drawVertices(
      ui.Vertices vertices, ui.BlendMode blendMode, ui.Paint paint) {}
}

class _RecordingPaintingContext extends PaintingContext {
  _RecordingPaintingContext(this._canvas, Rect paintBounds)
      : super(
          OffsetLayer(),
          ui.Rect.fromLTRB(
            paintBounds.left,
            paintBounds.top,
            paintBounds.right,
            paintBounds.bottom,
          ),
        );

  final _RecordingUiCanvas _canvas;

  @override
  ui.Canvas get canvas => _canvas;

  @override
  void paintChild(RenderObject child, ui.Offset offset) {
    // If this object composites into a layer, traverse to its children so we capture draws
    // instead of dropping picture layers.
    if (child.alwaysNeedsCompositing) {
      child.visitChildren((c) => paintChild(c, offset));
      return;
    }
    child.paint(this, offset);
  }

  @override
  PaintingContext createChildContext(ContainerLayer childLayer, Rect bounds) {
    // Keep using the same context so all draws hit the recording canvas.
    return this;
  }

  @override
  ClipRectLayer? pushClipRect(
    bool needsCompositing,
    ui.Offset offset,
    ui.Rect clipRect,
    PaintingContextCallback painter, {
    Clip clipBehavior = Clip.hardEdge,
    ClipRectLayer? oldLayer,
  }) {
    if (clipBehavior == Clip.none) {
      painter(this, offset);
      return oldLayer;
    }
    final ui.Rect off = clipRect.shift(offset);
    _canvas.save();
    _canvas.clipRect(off, doAntiAlias: clipBehavior != Clip.none);
    painter(this, offset);
    _canvas.restore();
    return oldLayer;
  }

  @override
  ClipRRectLayer? pushClipRRect(
    bool needsCompositing,
    ui.Offset offset,
    ui.Rect bounds,
    ui.RRect clipRRect,
    PaintingContextCallback painter, {
    Clip clipBehavior = Clip.antiAlias,
    ClipRRectLayer? oldLayer,
  }) {
    if (clipBehavior == Clip.none) {
      painter(this, offset);
      return oldLayer;
    }
    final ui.RRect off = clipRRect.shift(offset);
    _canvas.save();
    _canvas.clipRRect(off, doAntiAlias: clipBehavior != Clip.none);
    painter(this, offset);
    _canvas.restore();
    return oldLayer;
  }

  @override
  ClipPathLayer? pushClipPath(
    bool needsCompositing,
    ui.Offset offset,
    ui.Rect bounds,
    ui.Path clipPath,
    PaintingContextCallback painter, {
    Clip clipBehavior = Clip.antiAlias,
    ClipPathLayer? oldLayer,
  }) {
    if (clipBehavior == Clip.none) {
      painter(this, offset);
      return oldLayer;
    }
    final ui.Path path = clipPath.shift(offset);
    _canvas.save();
    _canvas.clipRect(path.getBounds(), doAntiAlias: clipBehavior != Clip.none);
    painter(this, offset);
    _canvas.restore();
    return oldLayer;
  }

  @override
  TransformLayer? pushTransform(
    bool needsCompositing,
    ui.Offset offset,
    Matrix4 transform,
    PaintingContextCallback painter, {
    TransformLayer? oldLayer,
  }) {
    final Matrix4 eff = Matrix4.translationValues(offset.dx, offset.dy, 0)
      ..multiply(transform)
      ..translate(-offset.dx, -offset.dy);
    _canvas.save();
    _canvas.transform(eff.storage);
    painter(this, offset);
    _canvas.restore();
    return oldLayer;
  }

  @override
  void pushLayer(
    ContainerLayer childLayer,
    PaintingContextCallback painter,
    ui.Offset offset, {
    ui.Rect? childPaintBounds,
  }) {
    painter(this, offset);
  }

  @override
  void addLayer(Layer layer) {}

  @override
  void appendLayer(Layer layer) {}

  @override
  ColorFilterLayer pushColorFilter(
    ui.Offset offset,
    ColorFilter colorFilter,
    PaintingContextCallback painter, {
    ColorFilterLayer? oldLayer,
  }) {
    painter(this, offset);
    return oldLayer ?? ColorFilterLayer();
  }

  @override
  OpacityLayer pushOpacity(
    ui.Offset offset,
    int alpha,
    PaintingContextCallback painter, {
    OpacityLayer? oldLayer,
  }) {
    painter(this, offset);
    return oldLayer ?? OpacityLayer();
  }
}

typedef OnPaintFrame = Future<void> Function(
    ReplayRecorderController controller);

OnPaintFrame flutterRenderViewOnPaintFrame() {
  return (ReplayRecorderController controller) async {
    final completer = Completer<void>();
    // Ensure a frame will be produced even if the app is idle
    WidgetsBinding.instance
      ..ensureVisualUpdate()
      ..addPostFrameCallback((_) {
        for (final renderView in RendererBinding.instance.renderViews) {
          if (!renderView.attached || renderView.child == null) continue;
          final adapter = _RecordingUiCanvas(controller);
          final bounds = renderView.paintBounds;
          final context = _RecordingPaintingContext(
            adapter,
            Rect.fromLTRB(
              bounds.left,
              bounds.top,
              bounds.right,
              bounds.bottom,
            ),
          );
          adapter.save();

          // Paint the full tree starting at the RenderView via PaintingContext API
          context.paintChild(renderView, ui.Offset.zero);
          adapter.restore();
          // stopRecordingIfNeeded is protected; no-op in minimal impl
          // no-op: stopRecordingIfNeeded is protected, and not needed here
        }
        completer.complete();
      });
    await completer.future;
  };
}
