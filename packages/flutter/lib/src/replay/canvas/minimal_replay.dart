import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

// Stable node id for the synthetic <canvas> element created in the FullSnapshot.
// Incremental canvas mutation events will reference this id.
const int kReplayCanvasNodeId = 3;

class CanvasCommand {
  CanvasCommand(this.name, this.args);
  final String name;
  final List<dynamic> args;
  Map<String, dynamic> toJson() => {'name': name, 'args': args};
}

class ReplayRecorderController {
  final List<CanvasCommand> _commands = <CanvasCommand>[];
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();

  void _record(CanvasCommand command) => _commands.add(command);
  // Public API for platform adapters to record commands directly
  void recordCommand(String name, List<dynamic> args) =>
      _record(CanvasCommand(name, args));
  void clear() => _commands.clear();
  bool get hasData => _commands.isNotEmpty;
  bool get hasMeaningfulData => _commands
      .any((c) => c.name.startsWith('draw') || c.name.startsWith('clip'));
  Stream<Map<String, dynamic>> get rrwebEvents => _events.stream;

  Map<String, dynamic> toRrwebCanvasEvent({
    required Size logicalSize,
    double devicePixelRatio = 1.0,
    int? timestampMs,
  }) {
    final int now = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
    // rrweb IncrementalSnapshot + CanvasMutation source
    const int kIncrementalSnapshotType = 3;
    const int kCanvasMutationSource = 9; // rrweb incremental source for canvas
    final int canvasPixelWidth = (logicalSize.width * devicePixelRatio).round();
    final int canvasPixelHeight =
        (logicalSize.height * devicePixelRatio).round();
    final List<Map<String, dynamic>> rrwebCommands = _toRrwebCanvasCommands(
      _commands,
      canvasPixelWidth,
      canvasPixelHeight,
      devicePixelRatio,
    );
    return {
      'type': kIncrementalSnapshotType,
      'timestamp': now,
      'data': {
        'source': kCanvasMutationSource,
        // Reference the synthetic <canvas> node created in the FullSnapshot
        'id': kReplayCanvasNodeId,
        // Help the consumer size the canvas correctly
        'pixelWidth': canvasPixelWidth,
        'pixelHeight': canvasPixelHeight,
        'logicalWidth': logicalSize.width,
        'logicalHeight': logicalSize.height,
        'devicePixelRatio': devicePixelRatio,
        // rrweb canvas plugin expects an array of 2D canvas commands
        'commands': rrwebCommands,
      },
    };
  }

  Map<String, dynamic> toRrwebCanvasAttributeEvent({
    required Size logicalSize,
    double devicePixelRatio = 1.0,
    int? timestampMs,
  }) {
    final int now = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
    const int kIncrementalSnapshotType = 3;
    const int kMutationSource = 0; // rrweb incremental source for DOM mutations
    final int pixelWidth = (logicalSize.width * devicePixelRatio).round();
    final int pixelHeight = (logicalSize.height * devicePixelRatio).round();
    return {
      'type': kIncrementalSnapshotType,
      'timestamp': now,
      'data': {
        'source': kMutationSource,
        'adds': <dynamic>[],
        'removes': <dynamic>[],
        'texts': <dynamic>[],
        'attributes': [
          {
            'id': kReplayCanvasNodeId,
            'attributes': {
              'width': pixelWidth.toString(),
              'height': pixelHeight.toString(),
              'style':
                  'width: ${logicalSize.width}px; height: ${logicalSize.height}px; display: block;'
            }
          }
        ]
      }
    };
  }

  // Convert recorded Flutter canvas commands to rrweb canvas plugin commands
  // Each command is a map like: { type: '2d', method: 'fillRect', args: [...] }
  // or a property set: { type: '2d', property: 'fillStyle', value: 'rgba(...)' }
  List<Map<String, dynamic>> _toRrwebCanvasCommands(
    List<CanvasCommand> commands,
    int canvasPixelWidth,
    int canvasPixelHeight,
    double devicePixelRatio,
  ) {
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    final double _logicalCanvasWidth = devicePixelRatio != 0
        ? canvasPixelWidth / devicePixelRatio
        : canvasPixelWidth.toDouble();
    final double _logicalCanvasHeight = devicePixelRatio != 0
        ? canvasPixelHeight / devicePixelRatio
        : canvasPixelHeight.toDouble();

    String _rgbaFromColorInt(int argb) {
      final int a = (argb >> 24) & 0xFF;
      final int r = (argb >> 16) & 0xFF;
      final int g = (argb >> 8) & 0xFF;
      final int b = (argb) & 0xFF;
      final double alpha = a / 255.0;
      return 'rgba($r, $g, $b, ${alpha.toStringAsFixed(3)})';
    }

    void _applyPaint(Map<String, dynamic> paint, {required bool forStroke}) {
      final String colorCss = _rgbaFromColorInt(paint['color'] as int);
      if (forStroke) {
        out.add({'type': '2d', 'property': 'strokeStyle', 'value': colorCss});
        final double strokeWidth =
            (paint['strokeWidth'] as num?)?.toDouble() ?? 1.0;
        out.add({'type': '2d', 'property': 'lineWidth', 'value': strokeWidth});
        final int? capIdx =
            paint['strokeCap'] as int?; // 0=butt,1=round,2=square
        if (capIdx != null) {
          const caps = ['butt', 'round', 'square'];
          out.add({'type': '2d', 'property': 'lineCap', 'value': caps[capIdx]});
        }
        final int? joinIdx =
            paint['strokeJoin'] as int?; // 0=miter,1=round,2=bevel
        if (joinIdx != null) {
          const joins = ['miter', 'round', 'bevel'];
          out.add(
              {'type': '2d', 'property': 'lineJoin', 'value': joins[joinIdx]});
        }
        final double? miter = (paint['strokeMiterLimit'] as num?)?.toDouble();
        if (miter != null) {
          out.add({'type': '2d', 'property': 'miterLimit', 'value': miter});
        }
      } else {
        out.add({'type': '2d', 'property': 'fillStyle', 'value': colorCss});
      }
      // BlendMode mapping (best-effort)
      final int? blendIdx = paint['blendMode'] as int?;
      if (blendIdx != null) {
        const List<String> gcos = [
          'source-over', // srcOver
          'source-in', // srcIn
          'source-out', // srcOut
          'source-atop', // srcATop
          'destination-over', // dstOver
          'destination-in', // dstIn
          'destination-out', // dstOut
          'destination-atop', // dstATop
          'lighter', // plus (approx)
          'copy', // modulate ~ copy (best-effort)
          'xor', // xor
          'multiply', // multiply
          'screen', // screen
          'overlay', // overlay
          'darken', // darken
          'lighten', // lighten
          'color-dodge', // colorDodge
          'color-burn', // colorBurn
          'hard-light', // hardLight
          'soft-light', // softLight
          'difference', // difference
          'exclusion', // exclusion
          'hue', // hue
          'saturation', // saturation
          'color', // color
          'luminosity', // luminosity
        ];
        final String gco = (blendIdx >= 0 && blendIdx < gcos.length)
            ? gcos[blendIdx]
            : 'source-over';
        out.add({
          'type': '2d',
          'property': 'globalCompositeOperation',
          'value': gco
        });
      }
      final bool? aa = paint['isAntiAlias'] as bool?;
      if (aa != null) {
        out.add(
            {'type': '2d', 'property': 'imageSmoothingEnabled', 'value': aa});
      }
    }

    Map<String, dynamic> _method(String name, List<dynamic> args) =>
        {'type': '2d', 'method': name, 'args': args};

    List<double>? _parseRectBoundsDynamic(dynamic arg) {
      if (arg is List) {
        final List<num> r = arg.cast<num>();
        return [
          r[0].toDouble(),
          r[1].toDouble(),
          r[2].toDouble(),
          r[3].toDouble()
        ];
      }
      if (arg is String) {
        // Expected formats like: Rect.fromLTRB(l, t, r, b)
        final RegExp re = RegExp(r"[-+]?[0-9]*\.?[0-9]+");
        final matches =
            re.allMatches(arg).map((m) => double.parse(m.group(0)!)).toList();
        if (matches.length >= 4) {
          return [matches[0], matches[1], matches[2], matches[3]];
        }
      }
      return null;
    }

    bool didEmitInitialNormalization = false;
    void _ensureInitialNormalization() {
      if (didEmitInitialNormalization) return;
      // Reset transform then scale so logical coords map to pixel canvas size.
      out.add(_method('setTransform', [1, 0, 0, 1, 0, 0]));
      if (devicePixelRatio != 1.0) {
        out.add(_method('scale', [devicePixelRatio, devicePixelRatio]));
      }
      // If future: pass DPR to this function and scale by it.
      didEmitInitialNormalization = true;
    }

    for (final CanvasCommand c in commands) {
      _ensureInitialNormalization();
      switch (c.name) {
        case 'save':
          out.add(_method('save', const []));
          break;
        case 'restore':
          out.add(_method('restore', const []));
          break;
        case 'saveLayer':
          // No direct 2d equivalent; approximate with save()
          out.add(_method('save', const []));
          break;
        case 'translate':
          out.add(_method('translate', [c.args[0], c.args[1]]));
          break;
        case 'scale':
          out.add(_method('scale', [c.args[0], c.args[1]]));
          break;
        case 'rotate':
          out.add(_method('rotate', [c.args[0]]));
          break;
        case 'transform':
          // Convert 4x4 to 2d a,b,c,d,e,f (best-effort)
          final List<dynamic> m = (c.args[0] as List).cast<dynamic>();
          if (m.length >= 14) {
            final double a = (m[0] as num).toDouble();
            final double b = (m[1] as num).toDouble();
            final double c_ = (m[4] as num).toDouble();
            final double d = (m[5] as num).toDouble();
            final double e = (m[12] as num).toDouble();
            final double f = (m[13] as num).toDouble();
            // Multiply current transform to preserve prior state
            out.add(_method('transform', [a, b, c_, d, e, f]));
          }
          break;
        case 'clipRect':
          final List<num> r = (c.args[0] as List).cast<num>();
          final int? op =
              (c.args.length > 1 && c.args[1] is int) ? c.args[1] as int : null;
          final double l = r[0].toDouble();
          final double t = r[1].toDouble();
          final double w = (r[2] - r[0]).toDouble();
          final double h = (r[3] - r[1]).toDouble();
          out.add(_method('beginPath', const []));
          if (op == 1) {
            // ClipOp.difference: clip the canvas except the rect
            out.add(_method(
                'rect', [0, 0, _logicalCanvasWidth, _logicalCanvasHeight]));
            out.add(_method('rect', [l, t, w, h]));
            out.add(_method('clip', const ['evenodd']));
          } else {
            // Default: intersect
            out.add(_method('rect', [l, t, w, h]));
            out.add(_method('clip', const []));
          }
          break;
        case 'clipRRect':
          final List<num> rr = (c.args[0] as List).cast<num>();
          // Some callers pass only [rrect, doAntiAlias] where the second arg is a bool.
          // Only treat the second arg as an op when it's actually an int.
          final int? op =
              (c.args.length > 1 && c.args[1] is int) ? c.args[1] as int : null;
          final double l = rr[0].toDouble();
          final double t = rr[1].toDouble();
          final double w = (rr[2] - rr[0]).toDouble();
          final double h = (rr[3] - rr[1]).toDouble();
          final double tlrx = rr.length > 4 ? rr[4].toDouble() : 0;
          final double tlry = rr.length > 5 ? rr[5].toDouble() : tlrx;
          final double trrx = rr.length > 6 ? rr[6].toDouble() : tlrx;
          final double trry = rr.length > 7 ? rr[7].toDouble() : trrx;
          final double brrx = rr.length > 8 ? rr[8].toDouble() : tlrx;
          final double brry = rr.length > 9 ? rr[9].toDouble() : brrx;
          final double blrx = rr.length > 10 ? rr[10].toDouble() : tlrx;
          final double blry = rr.length > 11 ? rr[11].toDouble() : blrx;
          out.add(_method('beginPath', const []));
          if (op == 1) {
            // difference: clip everything except this rrect
            out.add(_method(
                'rect', [0, 0, _logicalCanvasWidth, _logicalCanvasHeight]));
            out.add(_method('roundRect', [
              l,
              t,
              w,
              h,
              [
                [tlrx, tlry],
                [trrx, trry],
                [brrx, brry],
                [blrx, blry],
              ]
            ]));
            out.add(_method('clip', const ['evenodd']));
          } else {
            out.add(_method('roundRect', [
              l,
              t,
              w,
              h,
              [
                [tlrx, tlry],
                [trrx, trry],
                [brrx, brry],
                [blrx, blry],
              ]
            ]));
            out.add(_method('clip', const []));
          }
          break;
        case 'drawRect':
          final List<num> r = (c.args[0] as List).cast<num>();
          final Map<String, dynamic> p =
              (c.args[1] as Map).cast<String, dynamic>();
          // Clamp to canvas to avoid drawing outside of bounds
          double l = r[0].toDouble();
          double t = r[1].toDouble();
          double w = (r[2] - r[0]).toDouble();
          double h = (r[3] - r[1]).toDouble();
          // Normalize negative width/height
          if (w < 0) {
            l = l + w;
            w = -w;
          }
          if (h < 0) {
            t = t + h;
            h = -h;
          }
          // Clip to logical canvas bounds
          final double maxW = (_logicalCanvasWidth - l).clamp(0.0, w);
          final double maxH = (_logicalCanvasHeight - t).clamp(0.0, h);
          w = maxW;
          h = maxH;
          final bool stroke = (p['style'] as int? ?? 0) == 1;
          _applyPaint(p, forStroke: stroke);
          out.add(_method(stroke ? 'strokeRect' : 'fillRect', [l, t, w, h]));
          break;
        case 'drawRRect':
          final List<num> rr = (c.args[0] as List).cast<num>();
          final Map<String, dynamic> p =
              (c.args[1] as Map).cast<String, dynamic>();
          final double l = rr[0].toDouble();
          final double t = rr[1].toDouble();
          final double w = (rr[2] - rr[0]).toDouble();
          final double h = (rr[3] - rr[1]).toDouble();
          final double tlrx = rr.length > 4 ? rr[4].toDouble() : 0;
          final double tlry = rr.length > 5 ? rr[5].toDouble() : tlrx;
          final double trrx = rr.length > 6 ? rr[6].toDouble() : tlrx;
          final double trry = rr.length > 7 ? rr[7].toDouble() : trrx;
          final double brrx = rr.length > 8 ? rr[8].toDouble() : tlrx;
          final double brry = rr.length > 9 ? rr[9].toDouble() : brrx;
          final double blrx = rr.length > 10 ? rr[10].toDouble() : tlrx;
          final double blry = rr.length > 11 ? rr[11].toDouble() : blrx;
          final bool stroke = (p['style'] as int? ?? 0) == 1;
          _applyPaint(p, forStroke: stroke);
          out.add(_method('beginPath', const []));
          out.add(_method('roundRect', [
            l,
            t,
            w,
            h,
            [
              [tlrx, tlry],
              [trrx, trry],
              [brrx, brry],
              [blrx, blry],
            ]
          ]));
          out.add(_method(stroke ? 'stroke' : 'fill', const []));
          break;
        case 'drawDRRect':
          final List<num> outer = (c.args[0] as List).cast<num>();
          final List<num> inner = (c.args[1] as List).cast<num>();
          final Map<String, dynamic> p =
              (c.args[2] as Map).cast<String, dynamic>();
          final bool stroke = (p['style'] as int? ?? 0) == 1;
          _applyPaint(p, forStroke: stroke);
          double _l(List<num> r) => r[0].toDouble();
          double _t(List<num> r) => r[1].toDouble();
          double _w(List<num> r) => (r[2] - r[0]).toDouble();
          double _h(List<num> r) => (r[3] - r[1]).toDouble();
          List<List<double>> _radii(List<num> r) => [
                [
                  r.length > 4 ? r[4].toDouble() : 0,
                  r.length > 5
                      ? r[5].toDouble()
                      : (r.length > 4 ? r[4].toDouble() : 0)
                ],
                [
                  r.length > 6 ? r[6].toDouble() : 0,
                  r.length > 7
                      ? r[7].toDouble()
                      : (r.length > 6 ? r[6].toDouble() : 0)
                ],
                [
                  r.length > 8 ? r[8].toDouble() : 0,
                  r.length > 9
                      ? r[9].toDouble()
                      : (r.length > 8 ? r[8].toDouble() : 0)
                ],
                [
                  r.length > 10 ? r[10].toDouble() : 0,
                  r.length > 11
                      ? r[11].toDouble()
                      : (r.length > 10 ? r[10].toDouble() : 0)
                ],
              ];
          out.add(_method('beginPath', const []));
          out.add(_method('roundRect',
              [_l(outer), _t(outer), _w(outer), _h(outer), _radii(outer)]));
          out.add(_method('roundRect',
              [_l(inner), _t(inner), _w(inner), _h(inner), _radii(inner)]));
          out.add(_method(stroke ? 'stroke' : 'fill',
              stroke ? const [] : const ['evenodd']));
          break;
        case 'clipPath':
          final boundsCp = _parseRectBoundsDynamic(c.args[0]);
          if (boundsCp != null) {
            final double l = boundsCp[0];
            final double t = boundsCp[1];
            final double w = (boundsCp[2] - boundsCp[0]).abs();
            final double h = (boundsCp[3] - boundsCp[1]).abs();
            out.add(_method('beginPath', const []));
            out.add(_method('rect', [l, t, w, h]));
            out.add(_method('clip', const []));
          }
          break;
        case 'drawParagraph':
          final List<num> off = (c.args[0] as List).cast<num>();
          final double x = off[0].toDouble();
          final double y = off[1].toDouble();
          double w = (c.args[1] as num).toDouble();
          double h = (c.args[2] as num).toDouble();
          // Clamp within canvas bounds to avoid off-canvas paint
          w = (_logicalCanvasWidth - x).clamp(0.0, w);
          h = (_logicalCanvasHeight - y).clamp(0.0, h);
          out.add(_method('beginPath', const []));
          out.add(_method('rect', [x, y, w, h]));
          out.add(_method('fill', const []));
          break;
        case 'drawCircle':
          final List<num> cxy = (c.args[0] as List).cast<num>();
          final double radius = (c.args[1] as num).toDouble();
          final Map<String, dynamic> p =
              (c.args[2] as Map).cast<String, dynamic>();
          final bool stroke = (p['style'] as int? ?? 0) == 1;
          _applyPaint(p, forStroke: stroke);
          final double cx = cxy[0].toDouble();
          final double cy = cxy[1].toDouble();
          out.add(_method('beginPath', const []));
          out.add(_method('arc', [cx, cy, radius, 0, 2 * 3.141592653589793]));
          out.add(_method(stroke ? 'stroke' : 'fill', const []));
          break;
        case 'drawLine':
          final List<num> p1 = (c.args[0] as List).cast<num>();
          final List<num> p2 = (c.args[1] as List).cast<num>();
          final Map<String, dynamic> p =
              (c.args[2] as Map).cast<String, dynamic>();
          _applyPaint(p, forStroke: true);
          out.add(_method('beginPath', const []));
          out.add(_method('moveTo', [p1[0].toDouble(), p1[1].toDouble()]));
          out.add(_method('lineTo', [p2[0].toDouble(), p2[1].toDouble()]));
          out.add(_method('stroke', const []));
          break;
        case 'drawOval':
          final List<num> r = (c.args[0] as List).cast<num>();
          final Map<String, dynamic> p =
              (c.args[1] as Map).cast<String, dynamic>();
          final bool stroke = (p['style'] as int? ?? 0) == 1;
          _applyPaint(p, forStroke: stroke);
          final double x = r[0].toDouble();
          final double y = r[1].toDouble();
          final double rx = (r[2] - r[0]).abs().toDouble() / 2.0;
          final double ry = (r[3] - r[1]).abs().toDouble() / 2.0;
          final double cx = x + rx;
          final double cy = y + ry;
          out.add(_method('beginPath', const []));
          out.add(_method(
              'ellipse', [cx, cy, rx, ry, 0, 0, 2 * 3.141592653589793]));
          out.add(_method(stroke ? 'stroke' : 'fill', const []));
          break;
        // Unsupported or insufficient data; skip gracefully
        case 'drawPath':
          // Approximate by drawing the bounds of the path
          final bounds = _parseRectBoundsDynamic(c.args[0]);
          if (bounds != null) {
            final Map<String, dynamic> p =
                (c.args[1] as Map).cast<String, dynamic>();
            final bool stroke = (p['style'] as int? ?? 0) == 1;
            _applyPaint(p, forStroke: stroke);
            final double l = bounds[0];
            final double t = bounds[1];
            final double w = (bounds[2] - bounds[0]).abs();
            final double h = (bounds[3] - bounds[1]).abs();
            if (stroke) {
              out.add(_method('strokeRect', [l, t, w, h]));
            } else {
              out.add(_method('fillRect', [l, t, w, h]));
            }
          }
          break;
        case 'drawPaint':
          // Fill the entire canvas with the given paint
          final Map<String, dynamic> p =
              (c.args[0] as Map).cast<String, dynamic>();
          _applyPaint(p, forStroke: false);
          out.add(_method('fillRect', [
            0,
            0,
            _logicalCanvasWidth,
            _logicalCanvasHeight,
          ]));
          break;
        case 'drawColor':
          // Fill the entire canvas with the given color
          final int color = c.args[0] as int;
          final String colorCss = _rgbaFromColorInt(color);
          out.add({'type': '2d', 'property': 'fillStyle', 'value': colorCss});
          out.add(_method('fillRect', [
            0,
            0,
            _logicalCanvasWidth,
            _logicalCanvasHeight,
          ]));
          break;
        case 'drawImage':
        case 'drawImageRect':
          break;
        default:
          break;
      }
    }

    return out;
  }

  String toRrwebCanvasEventJson({
    required Size logicalSize,
    double devicePixelRatio = 1.0,
    int? timestampMs,
  }) =>
      jsonEncode(
        toRrwebCanvasEvent(
          logicalSize: logicalSize,
          devicePixelRatio: devicePixelRatio,
          timestampMs: timestampMs,
        ),
      );

  void emitRrwebEvent({
    required Size logicalSize,
    double devicePixelRatio = 1.0,
    int? timestampMs,
  }) {
    // First, emit an attributes update to ensure canvas has correct size.
    _events.add(
      toRrwebCanvasAttributeEvent(
        logicalSize: logicalSize,
        devicePixelRatio: devicePixelRatio,
        timestampMs: timestampMs,
      ),
    );
    // Then emit the actual canvas commands.
    _events.add(
      toRrwebCanvasEvent(
        logicalSize: logicalSize,
        devicePixelRatio: devicePixelRatio,
        timestampMs: timestampMs,
      ),
    );
  }
}

class _Serializer {
  static Map<String, dynamic> paint(Paint p) => {
        'color': p.color.value,
        'style': p.style.index,
        'strokeWidth': p.strokeWidth,
        'blendMode': p.blendMode.index,
        'isAntiAlias': p.isAntiAlias,
        'strokeCap': p.strokeCap.index,
        'strokeJoin': p.strokeJoin.index,
        'strokeMiterLimit': p.strokeMiterLimit,
      };
  static List<num> rect(Rect r) => [r.left, r.top, r.right, r.bottom];
  static List<num> rrect(RRect r) => [
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
  static List<num> offset(Offset o) => [o.dx, o.dy];
  static List<double> mat4(Float64List m) =>
      m.toList(growable: false).cast<double>();
}

abstract class ICanvas {
  void save();
  void restore();
  void saveLayer(Rect? bounds, Paint paint);
  void translate(double dx, double dy);
  void scale(double sx, [double? sy]);
  void rotate(double radians);
  void transform(Float64List matrix4);

  void clipRect(
    Rect rect, {
    ClipOp clipOp = ClipOp.intersect,
    bool doAntiAlias = true,
  });
  void clipRRect(RRect rrect, {bool doAntiAlias = true});
  void clipPath(String pathBounds, {bool doAntiAlias = true});

  void drawColor(Color color, BlendMode blendMode);
  void drawRect(Rect rect, Paint paint);
  void drawDRRect(RRect outer, RRect inner, Paint paint);
  void drawRRect(RRect rrect, Paint paint);
  void drawCircle(Offset c, double radius, Paint paint);
  void drawLine(Offset p1, Offset p2, Paint paint);
  void drawOval(Rect rect, Paint paint);
  void drawPath(String pathBounds, Paint paint);
  void drawPaint(Paint paint);
  void drawPoints(PointMode mode, List<Offset> points, Paint paint);
  void drawImage(Image image, Offset p, Paint paint);
  void drawImageRect(Image image, Rect src, Rect dst, Paint paint);
  void drawParagraph(Paragraph paragraph, Offset offset);

  int getSaveCount();
  Rect getLocalClipBounds();
  Rect getDestinationClipBounds();
  Float64List getTransform();
}

class RecordingCanvas implements ICanvas {
  RecordingCanvas({
    ICanvas? inner,
    required ReplayRecorderController controller,
  })  : _inner = inner ?? NullCanvas(),
        _controller = controller;

  final ICanvas _inner;
  final ReplayRecorderController _controller;

  void _cmd(String name, List<dynamic> args) {
    _controller._record(CanvasCommand(name, args));
  }

  void save() {
    _cmd('save', const []);
    _inner.save();
  }

  void restore() {
    _cmd('restore', const []);
    _inner.restore();
  }

  void saveLayer(Rect? bounds, Paint paint) {
    _cmd('saveLayer', [
      bounds != null ? _Serializer.rect(bounds) : null,
      _Serializer.paint(paint),
    ]);
    _inner.saveLayer(bounds, paint);
  }

  void translate(double dx, double dy) {
    _cmd('translate', [dx, dy]);
    _inner.translate(dx, dy);
  }

  void scale(double sx, [double? sy]) {
    _cmd('scale', [sx, sy ?? sx]);
    _inner.scale(sx, sy);
  }

  void rotate(double radians) {
    _cmd('rotate', [radians]);
    _inner.rotate(radians);
  }

  void transform(Float64List matrix4) {
    _cmd('transform', [_Serializer.mat4(matrix4)]);
    _inner.transform(matrix4);
  }

  void clipRect(
    Rect rect, {
    ClipOp clipOp = ClipOp.intersect,
    bool doAntiAlias = true,
  }) {
    _cmd('clipRect', [_Serializer.rect(rect), clipOp.index, doAntiAlias]);
    _inner.clipRect(rect, clipOp: clipOp, doAntiAlias: doAntiAlias);
  }

  void clipRRect(RRect rrect, {bool doAntiAlias = true}) {
    _cmd('clipRRect', [_Serializer.rrect(rrect), doAntiAlias]);
    _inner.clipRRect(rrect, doAntiAlias: doAntiAlias);
  }

  void clipPath(String pathBounds, {bool doAntiAlias = true}) {
    _cmd('clipPath', [pathBounds, doAntiAlias]);
    _inner.clipPath(pathBounds, doAntiAlias: doAntiAlias);
  }

  void drawColor(Color color, BlendMode blendMode) {
    _cmd('drawColor', [color.value, blendMode.index]);
    _inner.drawColor(color, blendMode);
  }

  void drawRect(Rect rect, Paint paint) {
    _cmd('drawRect', [_Serializer.rect(rect), _Serializer.paint(paint)]);
    _inner.drawRect(rect, paint);
  }

  void drawDRRect(RRect outer, RRect inner, Paint paint) {
    _cmd('drawDRRect', [
      _Serializer.rrect(outer),
      _Serializer.rrect(inner),
      _Serializer.paint(paint),
    ]);
    _inner.drawDRRect(outer, inner, paint);
  }

  void drawRRect(RRect rrect, Paint paint) {
    _cmd('drawRRect', [_Serializer.rrect(rrect), _Serializer.paint(paint)]);
    _inner.drawRRect(rrect, paint);
  }

  void drawCircle(Offset c, double radius, Paint paint) {
    _cmd('drawCircle', [
      _Serializer.offset(c),
      radius,
      _Serializer.paint(paint),
    ]);
    _inner.drawCircle(c, radius, paint);
  }

  void drawLine(Offset p1, Offset p2, Paint paint) {
    _cmd('drawLine', [
      _Serializer.offset(p1),
      _Serializer.offset(p2),
      _Serializer.paint(paint),
    ]);
    _inner.drawLine(p1, p2, paint);
  }

  void drawOval(Rect rect, Paint paint) {
    _cmd('drawOval', [_Serializer.rect(rect), _Serializer.paint(paint)]);
    _inner.drawOval(rect, paint);
  }

  void drawPath(String pathBounds, Paint paint) {
    _cmd('drawPath', [pathBounds, _Serializer.paint(paint)]);
    _inner.drawPath(pathBounds, paint);
  }

  void drawPaint(Paint paint) {
    _cmd('drawPaint', [_Serializer.paint(paint)]);
    _inner.drawPaint(paint);
  }

  void drawPoints(PointMode pointMode, List<Offset> points, Paint paint) {
    _cmd('drawPoints', [
      pointMode.index,
      points.map(_Serializer.offset).toList(),
      _Serializer.paint(paint),
    ]);
    _inner.drawPoints(pointMode, points, paint);
  }

  void drawImage(Image image, Offset p, Paint paint) {
    _cmd('drawImage', [
      _Serializer.offset(p),
      image.width,
      image.height,
      _Serializer.paint(paint),
    ]);
    _inner.drawImage(image, p, paint);
  }

  void drawImageRect(Image image, Rect src, Rect dst, Paint paint) {
    _cmd('drawImageRect', [
      _Serializer.rect(src),
      _Serializer.rect(dst),
      image.width,
      image.height,
      _Serializer.paint(paint),
    ]);
    _inner.drawImageRect(image, src, dst, paint);
  }

  void drawParagraph(Paragraph paragraph, Offset offset) {
    _cmd('drawParagraph', [
      _Serializer.offset(offset),
      paragraph.width,
      paragraph.height,
    ]);
    _inner.drawParagraph(paragraph, offset);
  }

  int getSaveCount() => _inner.getSaveCount();
  Rect getLocalClipBounds() => _inner.getLocalClipBounds();
  Rect getDestinationClipBounds() => _inner.getDestinationClipBounds();
  Float64List getTransform() => _inner.getTransform();
}

class NullCanvas implements ICanvas {
  void clipPath(String pathBounds, {bool doAntiAlias = true}) {}
  void clipRect(
    Rect rect, {
    ClipOp clipOp = ClipOp.intersect,
    bool doAntiAlias = true,
  }) {}
  void clipRRect(RRect rrect, {bool doAntiAlias = true}) {}
  void drawCircle(Offset c, double radius, Paint paint) {}
  void drawColor(Color color, BlendMode blendMode) {}
  void drawDRRect(RRect outer, RRect inner, Paint paint) {}
  void drawImage(Image image, Offset p, Paint paint) {}
  void drawImageRect(Image image, Rect src, Rect dst, Paint paint) {}
  void drawLine(Offset p1, Offset p2, Paint paint) {}
  void drawOval(Rect rect, Paint paint) {}
  void drawPaint(Paint paint) {}
  void drawParagraph(Paragraph paragraph, Offset offset) {}
  void drawPath(String pathBounds, Paint paint) {}
  void drawPoints(PointMode mode, List<Offset> points, Paint paint) {}
  void drawRect(Rect rect, Paint paint) {}
  void drawRRect(RRect rrect, Paint paint) {}
  int getSaveCount() => 0;
  Rect getDestinationClipBounds() => const Rect.fromLTWH(0, 0, 0, 0);
  Rect getLocalClipBounds() => const Rect.fromLTWH(0, 0, 0, 0);
  Float64List getTransform() => Float64List(16);
  void restore() {}
  void rotate(double radians) {}
  void save() {}
  void saveLayer(Rect? bounds, Paint paint) {}
  void scale(double sx, [double? sy]) {}
  void transform(Float64List matrix4) {}
  void translate(double dx, double dy) {}
}

class PeriodicRenderViewCapturer {
  PeriodicRenderViewCapturer({
    required this.controller,
    required this.logicalSize,
    this.devicePixelRatio = 1.0,
    required this.onPaintFrame,
    this.alwaysCapture = false,
  });
  final ReplayRecorderController controller;
  final Size logicalSize;
  final double devicePixelRatio;
  // Paint callback should drive a frame and record into the controller
  final Future<void> Function(ReplayRecorderController controller) onPaintFrame;
  final bool alwaysCapture;
  Timer? _timer;
  void start() {
    stop();
    Timer.periodic(Duration(seconds: 1), (_) => _captureOnce());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _captureOnce() async {
    controller.clear();
    await onPaintFrame(controller);
    if (!alwaysCapture && !controller.hasMeaningfulData) {
      return;
    }
    controller.emitRrwebEvent(
      logicalSize: logicalSize,
      devicePixelRatio: devicePixelRatio,
    );
  }
}
