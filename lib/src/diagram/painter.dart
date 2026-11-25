import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/motion.dart';
import '../foundation/typography.dart';
import '../painting/shapes.dart';
import '../painting/text.dart';
import '../widgets/icon.dart';
import 'geometry.dart';
import 'metrics.dart';
import 'model.dart';

/// The timing of a diagram's entrance: nodes pop in one after another, then
/// the wires are drawn one after another.
///
/// A node takes 0.32s in four steps and the next starts 22ms later; a wire
/// takes 0.8s in sixteen steps and the next starts 90ms later. In a large
/// diagram the gaps shrink so the whole entrance stays short.
@immutable
class KkDiagramEntrance {
  const KkDiagramEntrance({required this.nodes, required this.wires});

  /// Number of nodes.
  final int nodes;

  /// Number of wires.
  final int wires;

  static const double _lead = 200;
  static const double _nodeTime = 320;
  static const double _wireTime = 800;

  double get _nodeGap => nodes <= 1 ? 0 : math.min(22, 660 / (nodes - 1));
  double get _wireGap => wires <= 1 ? 0 : math.min(90, 900 / (wires - 1));
  double get _wireLead => _lead + _nodeGap * math.max(0, nodes - 1) + _nodeTime / 2;

  /// The whole entrance, start to finish.
  Duration get total {
    final double nodeEnd = _lead + _nodeGap * math.max(0, nodes - 1) + _nodeTime;
    final double wireEnd = wires == 0 ? 0 : _wireLead + _wireGap * (wires - 1) + _wireTime;
    return Duration(milliseconds: math.max(nodeEnd, wireEnd).ceil());
  }

  /// Progress (0 to 1) of node [index] when the entrance is at [t] (0 to 1).
  double node(int index, double t) {
    if (t >= 1) return 1;
    final double ms = t * total.inMilliseconds;
    return ((ms - _lead - _nodeGap * index) / _nodeTime).clamp(0.0, 1.0);
  }

  /// Progress (0 to 1) of wire [index] when the entrance is at [t] (0 to 1).
  double wire(int index, double t) {
    if (t >= 1) return 1;
    final double ms = t * total.inMilliseconds;
    return ((ms - _wireLead - _wireGap * index) / _wireTime).clamp(0.0, 1.0);
  }

  @override
  bool operator ==(Object other) => other is KkDiagramEntrance && other.nodes == nodes && other.wires == wires;

  @override
  int get hashCode => Object.hash(nodes, wires);
}

/// Draws a placed diagram on a canvas in the KEIKAI grammar.
///
/// The painter is split into layers so that only the moving parts need to be
/// drawn every frame: [paintWires], then [paintFlow] and [paintHalos] (which
/// move), then [paintNodes] and [paintSelection]. [paint] does all of them.
///
/// Strokes keep their width whatever the canvas scale is: pass the scale the
/// canvas is drawn at as `scale`.
@immutable
class KkDiagramPainter {
  const KkDiagramPainter({
    required this.geometry,
    required this.colors,
    required this.type,
    this.metrics = const KkNodeMetrics(),
    this.ground,
    this.arrows = true,
    this.hovered,
    this.focused,
    this.selected,
    this.origin = Offset.zero,
  });

  final KkDiagramGeometry geometry;
  final KkColors colors;
  final KkTypography type;

  /// The metrics the diagram was laid out with (for the text sizes).
  final KkNodeMetrics metrics;

  /// The colour behind the diagram. Symbols are filled with it and text sits
  /// on it, so wires never strike through a label. Defaults to the panel
  /// colour (bg-100).
  final Color? ground;

  /// Draw arrow heads at all.
  final bool arrows;

  /// Id of the node under the pointer.
  final String? hovered;

  /// Id of the node with keyboard focus.
  final String? focused;

  /// Id of the selected node.
  final String? selected;

  /// Where the diagram's origin sits on the canvas.
  final Offset origin;

  Color get _ground => ground ?? colors.bg100;

  KkDiagram get _diagram => geometry.diagram;

  /// Draws everything at once: a finished diagram at time [time].
  void paint(Canvas canvas, {Duration time = Duration.zero, double scale = 1, List<String>? info}) {
    paintWires(canvas, scale: scale);
    paintFlow(canvas, time, scale: scale);
    paintLabels(canvas);
    paintNodes(canvas, scale: scale);
    paintHalos(canvas, time, scale: scale);
    paintSelection(canvas, scale: scale, info: info);
  }

  // ── wires ───────────────────────────────────────────────────────────────

  bool _near(KkDiagramEdge e) {
    final String? h = hovered ?? focused;
    return h != null && (e.from == h || e.to == h);
  }

  Color _wireColor(KkDiagramEdge e, bool near) {
    if (near && e.active) return colors.signal;
    switch (e.level) {
      case KkLevel.caution:
        return colors.caution;
      case KkLevel.critical:
        return colors.alert;
      case KkLevel.offline:
        return colors.offline;
      case KkLevel.nominal:
      case null:
        break;
    }
    if (near) return colors.inkDim;
    return e.active ? colors.signal : colors.line;
  }

  /// Draws the wires and their arrow heads.
  ///
  /// [progress] gives how much of each wire is drawn (0 to 1) during the
  /// entrance; a head appears when its wire is complete.
  void paintWires(Canvas canvas, {double scale = 1, double Function(int wire)? progress}) {
    if (geometry.routes.isEmpty) return;
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.miter
      ..strokeMiterLimit = 4;
    for (int i = 0; i < geometry.routes.length; i++) {
      final KkEdgeRoute route = geometry.routes[i];
      if (route.isEmpty || i >= _diagram.edges.length) continue;
      final KkDiagramEdge e = _diagram.edges[i];
      final double t = progress == null ? 1.0 : const KkSteps(16).transform(progress(i).clamp(0.0, 1.0));
      if (t <= 0) continue;
      final bool near = _near(e);
      paint
        ..color = _wireColor(e, near)
        ..strokeWidth = ((near || e.level == KkLevel.critical) ? 2.0 : 1.5) / scale;
      final List<Offset> points = t >= 1 ? route.points : route.trimmed(route.length * t);
      if (points.length < 2) continue;
      Path path = Path()..addPolygon(points, false);
      if (e.level == KkLevel.offline) path = kkDashPath(path, const <double>[3, 4]);
      canvas.drawPath(path, paint);
      if (t < 1) continue;
      if (arrows && e.arrow) {
        final Offset tip = route.points.last;
        final Offset d = route.endDirection;
        final Offset n = Offset(-d.dy, d.dx);
        const double a = 4.5;
        canvas.drawPath(
          Path()
            ..moveTo(tip.dx - (d.dx + n.dx) * a, tip.dy - (d.dy + n.dy) * a)
            ..lineTo(tip.dx, tip.dy)
            ..lineTo(tip.dx - (d.dx - n.dx) * a, tip.dy - (d.dy - n.dy) * a),
          paint,
        );
      }
    }
    canvas.restore();
  }

  /// Draws the wire labels: 9px mono on a ground-black backing, each on a leg
  /// of its own wire. They are drawn after the flow marks so nothing runs
  /// through the text.
  void paintLabels(Canvas canvas, {double Function(int wire)? progress}) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    final TextStyle labelStyle = type.mono(9 * metrics.textScale / type.scale, color: colors.inkDim, spacingEm: 0.04);
    for (int i = 0; i < geometry.routes.length && i < _diagram.edges.length; i++) {
      final String? label = _diagram.edges[i].label;
      if (label == null || label.isEmpty || geometry.routes[i].isEmpty) continue;
      if (progress != null && progress(i) < 1) continue;
      final TextPainter tp = kkLayoutText(label, labelStyle);
      final Offset at = geometry.labelAnchor(i);
      final Rect box = Rect.fromCenter(center: at, width: tp.width + 8, height: tp.height + 4);
      canvas.drawRect(box, Paint()..color = colors.bg000);
      tp.paint(canvas, Offset(at.dx - tp.width / 2, at.dy - tp.height / 2));
      tp.dispose();
    }
    canvas.restore();
  }

  /// Whether anything in the diagram moves: flow marks or alarm halos.
  bool get moves {
    for (final KkDiagramEdge e in _diagram.edges) {
      if (e.flow != KkEdgeFlow.none) return true;
    }
    for (final KkDiagramNode n in _diagram.nodes) {
      if (n.level == KkLevel.critical) return true;
    }
    return false;
  }

  /// Draws the flow marks at [time]: short dashes travelling along the wires
  /// that flow, 16px a second.
  void paintFlow(Canvas canvas, Duration time, {double scale = 1, double Function(int wire)? progress}) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..strokeWidth = 3 / scale;
    const double on = 2;
    const double period = 16;
    final double travelled = time.inMicroseconds / Duration.microsecondsPerSecond * period;
    for (int i = 0; i < geometry.routes.length && i < _diagram.edges.length; i++) {
      final KkDiagramEdge e = _diagram.edges[i];
      if (e.flow == KkEdgeFlow.none) continue;
      final KkEdgeRoute route = geometry.routes[i];
      if (route.isEmpty) continue;
      if (progress != null && progress(i) < 1) continue;
      paint.color = colors.level(e.level, fallback: colors.signal);
      final double shift = e.flow == KkEdgeFlow.forward ? travelled % period : period - travelled % period;
      _paintDashes(canvas, route.points, shift - period, on, period, paint);
    }
    canvas.restore();
  }

  static void _paintDashes(Canvas canvas, List<Offset> pts, double first, double on, double period, Paint paint) {
    final List<double> at = List<double>.filled(pts.length, 0);
    for (int i = 1; i < pts.length; i++) {
      at[i] = at[i - 1] + (pts[i] - pts[i - 1]).distance;
    }
    final double total = at.last;
    if (total <= 0) return;
    int seg = 1;
    Offset point(double d) {
      while (seg < pts.length - 1 && at[seg] < d) {
        seg++;
      }
      final double len = at[seg] - at[seg - 1];
      return len <= 0 ? pts[seg] : Offset.lerp(pts[seg - 1], pts[seg], (d - at[seg - 1]) / len)!;
    }

    for (double d = first; d < total; d += period) {
      final double a = math.max(d, 0);
      final double b = math.min(d + on, total);
      if (b <= a) continue;
      final Offset start = point(a);
      final int startSeg = seg;
      final Offset end = point(b);
      if (seg == startSeg) {
        canvas.drawLine(start, end, paint);
      } else {
        final Path p = Path()..moveTo(start.dx, start.dy);
        for (int k = startSeg; k < seg; k++) {
          p.lineTo(pts[k].dx, pts[k].dy);
        }
        p.lineTo(end.dx, end.dy);
        canvas.drawPath(p, paint);
      }
    }
  }

  // ── nodes ───────────────────────────────────────────────────────────────

  static const KkKeyframes _popOpacity = KkKeyframes(<double>[0, 0.5, 1], <double>[0, 1, 1], steps: 4);
  static const KkKeyframes _popScale = KkKeyframes(<double>[0, 0.5, 1], <double>[0.5, 1.08, 1], steps: 4);

  /// Draws the symbols, their status flags and their text.
  ///
  /// [progress] gives the pop-in of each node (0 to 1) during the entrance.
  void paintNodes(Canvas canvas, {double scale = 1, double Function(int node)? progress}) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    for (int i = 0; i < _diagram.nodes.length; i++) {
      final KkDiagramNode node = _diagram.nodes[i];
      final KkNodePlacement? place = geometry.nodes[node.id];
      if (place == null) continue;
      final double t = progress == null ? 1.0 : progress(i).clamp(0.0, 1.0);
      if (t <= 0) continue;
      if (t >= 1) {
        _paintNode(canvas, node, place, scale);
        continue;
      }
      final double opacity = _popOpacity.transform(t);
      final double grow = _popScale.transform(t);
      if (opacity <= 0) continue;
      final Offset c = place.shape.center;
      canvas.saveLayer(
        place.bounds.inflate(12),
        Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
      );
      canvas.translate(c.dx, c.dy);
      canvas.scale(grow);
      canvas.translate(-c.dx, -c.dy);
      _paintNode(canvas, node, place, scale);
      canvas.restore();
    }
    canvas.restore();
  }

  void _paintNode(Canvas canvas, KkDiagramNode node, KkNodePlacement place, double scale) {
    final Rect r = place.shape;
    final KkLevel? level = node.level;
    final Color lv = colors.level(level, fallback: colors.signal);
    final bool lit = node.id == hovered || node.id == focused;
    final bool critical = level == KkLevel.critical;
    final bool offline = level == KkLevel.offline;
    final Path outline = kkNodePath(node.kind, r);
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.miter
      ..strokeWidth = (node.kind == KkNodeKind.hub ? 2.5 : 1.5) / scale
      ..color = lv;

    if (node.kind == KkNodeKind.leaf) {
      if (offline || (lit && !critical)) {
        // Hollow: an offline leaf, or any leaf under the pointer.
        canvas.drawPath(outline, Paint()..color = lit ? colors.bg300 : _ground);
        canvas.drawPath(outline, stroke);
      } else {
        canvas.drawPath(outline, Paint()..color = lv);
      }
    } else {
      final Color fill = critical ? colors.alert : (lit ? colors.bg300 : _ground);
      canvas.drawPath(outline, Paint()..color = fill);
      canvas.drawPath(offline ? kkDashPath(outline, const <double>[3, 3]) : outline, stroke);
      final double core = math.min(node.kind == KkNodeKind.hub ? 8.0 : 6.0, r.shortestSide / 3);
      canvas.drawRect(
        Rect.fromCenter(center: r.center, width: core, height: core),
        Paint()..color = critical ? colors.onFill : lv,
      );
      if (level != null && level != KkLevel.nominal && r.shortestSide >= 16) {
        final Offset at = Offset(r.right - 2, r.top + 2);
        canvas.drawRect(Rect.fromCenter(center: at, width: 12, height: 12), Paint()..color = colors.bg000);
        kkPaintIcon(canvas, Rect.fromCenter(center: at, width: 10, height: 10), kkStatusIcon(level), lv);
      }
    }
    _paintText(canvas, node, place);
  }

  void _paintText(Canvas canvas, KkDiagramNode node, KkNodePlacement place) {
    final Rect? box = place.text;
    if (box == null || !metrics.showText) return;
    final bool beside = box.left >= place.shape.right - 0.5;
    final bool focus = node.id == focused;
    if (_ground.a > 0 && geometry.coveredTexts.contains(node.id)) {
      canvas.drawRect(box.inflate(1), Paint()..color = _ground);
    }
    final double k = 1 / type.scale;
    TextStyle code = type.mono(metrics.codePx * k, weight: FontWeight.w600, color: focus ? colors.focus : colors.ink);
    if (focus) {
      code = code.copyWith(decoration: TextDecoration.underline, decorationColor: colors.focus);
    }
    final TextPainter tp = kkLayoutText(node.text, code);
    tp.paint(canvas, Offset(beside ? box.left : box.center.dx - tp.width / 2, box.top));
    final double second = box.top + tp.height + metrics.lineGap;
    tp.dispose();

    final String? cjk = node.cjk;
    final String? label = node.label;
    final bool hasCjk = cjk != null && cjk.isNotEmpty;
    final bool hasLabel = label != null && label.isNotEmpty;
    if (!hasCjk && !hasLabel) return;
    final TextPainter? cp = hasCjk ? kkLayoutText(cjk, type.display(metrics.cjkPx * k, color: colors.ink)) : null;
    final TextPainter? lp = hasLabel
        ? kkLayoutText(
            label,
            type.mono(metrics.labelPx * k, color: colors.inkDim, spacingEm: KkNodeMetrics.labelSpacing),
          )
        : null;
    final double cw = cp == null ? 0 : cp.width * KkNodeMetrics.cjkSqueeze;
    final double gap = cp != null && lp != null ? 4 : 0;
    final double width = cw + gap + (lp?.width ?? 0);
    final double lineHeight = math.max(cp?.height ?? 0, lp?.height ?? 0);
    double x = beside ? box.left : box.center.dx - width / 2;
    if (cp != null) {
      canvas.save();
      canvas.translate(x, second + (lineHeight - cp.height) / 2);
      canvas.scale(KkNodeMetrics.cjkSqueeze, 1);
      cp.paint(canvas, Offset.zero);
      canvas.restore();
      x += cw + gap;
      cp.dispose();
    }
    if (lp != null) {
      lp.paint(canvas, Offset(x, second + (lineHeight - lp.height) / 2));
      lp.dispose();
    }
  }

  /// Draws the alarm halo round every critical node. It blinks every 1.2s:
  /// full for one half, dim for the other.
  void paintHalos(Canvas canvas, Duration time, {double scale = 1, double Function(int node)? progress}) {
    final bool dim = kkPhaseAt(time, KkMotion.blink) == 1;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / scale
      ..color = dim ? kkFade(colors.alert, 0.2) : colors.alert;
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    for (int i = 0; i < _diagram.nodes.length; i++) {
      final KkDiagramNode node = _diagram.nodes[i];
      if (node.level != KkLevel.critical) continue;
      if (progress != null && progress(i) < 1) continue;
      final KkNodePlacement? place = geometry.nodes[node.id];
      if (place == null) continue;
      canvas.drawPath(kkNodePath(node.kind, place.shape.inflate(3)), paint);
    }
    canvas.restore();
  }

  /// The lines shown on the info plate of [node] when it has none of its own:
  /// its label, its status and how many wires meet it.
  List<String> defaultInfo(KkDiagramNode node) {
    final int inCount = _diagram.incoming(node.id).length;
    final int outCount = _diagram.outgoing(node.id).length;
    final String? label = node.label;
    final KkLevel? level = node.level;
    return <String>[
      if (label != null && label.isNotEmpty) label,
      if (level != null) '${level.word} ${level.cjk}',
      'IN ${inCount.toString().padLeft(2, '0')} · OUT ${outCount.toString().padLeft(2, '0')}',
    ];
  }

  /// Draws the selection: a focus-coloured ring round the selected symbol
  /// and, when [plate] is true, a plate with a leader line carrying the
  /// node's code and the [info] lines (by default the node's own, or
  /// [defaultInfo]).
  ///
  /// [view] is the part of the canvas that can be seen; the plate is put on
  /// the side of the node where it stays inside it and covers the least.
  void paintSelection(Canvas canvas, {double scale = 1, List<String>? info, bool plate = true, Rect? view}) {
    final String? id = selected;
    if (id == null) return;
    final KkDiagramNode? node = _diagram.nodeById(id);
    final KkNodePlacement? place = geometry.nodes[id];
    if (node == null || place == null) return;
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.drawPath(
      kkNodePath(node.kind, place.shape.inflate(4)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 / scale
        ..color = colors.focus,
    );
    final List<String> lines = info ?? (node.info.isNotEmpty ? node.info : defaultInfo(node));
    if (plate) {
      final double k = metrics.textScale / type.scale;
      final TextStyle titleStyle = type.mono(10 * k, weight: FontWeight.w600, color: colors.ink);
      final TextStyle lineStyle = type.mono(10 * k, color: colors.inkDim);
      final String? cjk = node.cjk;
      final String title = cjk != null && cjk.isNotEmpty ? '${node.text}  $cjk' : node.text;
      final List<TextPainter> painters = <TextPainter>[
        kkLayoutText(title, titleStyle),
        for (final String line in lines) kkLayoutText(line, lineStyle),
      ];
      double width = 0;
      for (final TextPainter tp in painters) {
        width = math.max(width, tp.width);
      }
      const double pad = 8;
      const double lead = 4;
      final Size size = Size(
        (width + pad * 2).ceilToDouble(),
        pad * 2 + painters.first.height + (painters.length - 1) * (10 * metrics.textScale + lead),
      );
      final (Rect box, List<Offset> leader) = infoPlate(id, size, view: view);
      final Paint line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 / scale
        ..color = colors.signal;
      canvas.drawPath(Path()..addPolygon(leader, false), line);
      canvas.drawRect(box, Paint()..color = colors.bg200);
      canvas.drawRect(box.deflate(0.5 / scale), line);
      double y = box.top + pad;
      for (int i = 0; i < painters.length; i++) {
        painters[i].paint(canvas, Offset(box.left + pad, y));
        y += (i == 0 ? painters[i].height : 10 * metrics.textScale) + lead;
        painters[i].dispose();
      }
    }
    canvas.restore();
  }

  /// Where the info plate of node [id] goes when it is [size] big, and the
  /// leader line that ties it to the node, both in diagram coordinates.
  ///
  /// The plate goes up and to the right unless that side would leave [view]
  /// (the visible part of the diagram, in the coordinates of the painter's
  /// canvas) or cover more of the diagram than another side. It never covers
  /// the node's own text.
  (Rect, List<Offset>) infoPlate(String id, Size size, {Rect? view}) {
    final KkNodePlacement? place = geometry.nodes[id];
    if (place == null) return (Rect.zero, const <Offset>[]);
    final Rect shape = place.shape;
    final Rect seen =
        (view?.shift(-origin) ??
                Rect.fromLTRB(-origin.dx, -origin.dy, geometry.size.width + origin.dx, geometry.size.height + origin.dy))
            .deflate(2);
    // Beside the node the plate clears the text as well as the symbol; below
    // it hangs from the text.
    final Rect? text = place.text;
    final bool textBelow = text != null && text.top >= shape.bottom;
    final bool textRight = text != null && text.left >= shape.right;
    final Rect hang = text == null ? shape : shape.expandToInclude(text);
    bool right = true;
    int rise = 1; // 1 above, 0 level, -1 below
    Rect box = Rect.zero;
    double least = double.infinity;
    const List<(bool, int)> sides = <(bool, int)>[(true, 1), (true, 0), (false, 1), (false, 0), (true, -1), (false, -1)];
    for (int s = 0; s < sides.length; s++) {
      final (bool r, int v) = sides[s];
      final double top = switch (v) {
        1 => shape.top - 12 - size.height,
        0 => shape.center.dy - size.height / 2,
        _ => hang.bottom + 12,
      };
      final double left = switch (v) {
        1 => r ? shape.right + 16 : shape.left - 16 - size.width,
        0 => r ? hang.right + 16 : hang.left - 16 - size.width,
        _ when textBelow => r ? hang.right + 12 : hang.left - 12 - size.width,
        _ => r ? shape.right + 16 : shape.left - 16 - size.width,
      };
      final Rect candidate = Offset(left.roundToDouble(), top.roundToDouble()) & size;
      final Rect inside = candidate.intersect(seen);
      double cost = candidate.width * candidate.height - math.max(0, inside.width) * math.max(0, inside.height);
      cost = cost * 20 + s;
      for (final MapEntry<String, KkNodePlacement> other in geometry.nodes.entries) {
        if (other.key == id) continue;
        final Rect hit = candidate.intersect(other.value.bounds);
        if (hit.width > 0 && hit.height > 0) cost += hit.width * hit.height * 4;
      }
      for (int e = 0; e < geometry.routes.length; e++) {
        final List<Offset> pts = geometry.routes[e].points;
        for (int k = 1; k < pts.length; k++) {
          final Rect leg = Rect.fromPoints(pts[k - 1], pts[k]).inflate(1);
          if (leg.overlaps(candidate)) cost += 120;
        }
      }
      if (cost < least) {
        least = cost;
        right = r;
        rise = v;
        box = candidate;
      }
    }
    if (rise == 0) {
      final Offset from = Offset(right ? (textRight ? hang.right : shape.right) : shape.left, shape.center.dy);
      return (box, <Offset>[from, Offset(right ? box.left : box.right, shape.center.dy)]);
    }
    final bool up = rise > 0;
    // Below a node with its text underneath, the leader starts at the text.
    final Rect base = !up && textBelow ? hang : shape;
    final Offset from = Offset(right ? base.right : base.left, up ? base.top : base.bottom);
    final Offset corner = Offset(right ? box.left : box.right, up ? box.bottom : box.top);
    final double run = math.min((corner.dx - from.dx).abs(), (corner.dy - from.dy).abs());
    final Offset knee = from + Offset(right ? run : -run, up ? -run : run);
    return (box, <Offset>[from, if ((knee - corner).distance > 0.01) knee, corner]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KkDiagramPainter &&
        other.geometry == geometry &&
        other.colors == colors &&
        other.type == type &&
        other.metrics == metrics &&
        other.ground == ground &&
        other.arrows == arrows &&
        other.hovered == hovered &&
        other.focused == focused &&
        other.selected == selected &&
        other.origin == origin;
  }

  @override
  int get hashCode =>
      Object.hash(geometry, colors, type, metrics, ground, arrows, hovered, focused, selected, origin);
}

/// A small picture of one node symbol, for legends. Paints the symbol of
/// [kind] centred in [rect] the way the diagram draws it.
void kkPaintNodeSymbol(
  Canvas canvas,
  Rect rect,
  KkNodeKind kind, {
  required KkColors colors,
  KkLevel? level,
  Color? ground,
}) {
  final KkDiagram d = KkDiagram(nodes: <KkDiagramNode>[KkDiagramNode('n', kind: kind, level: level, size: rect.size)]);
  final KkDiagramGeometry g = KkDiagramGeometry(
    diagram: d,
    size: rect.size,
    nodes: <String, KkNodePlacement>{'n': KkNodePlacement(shape: rect, bounds: rect)},
    routes: const <KkEdgeRoute>[],
  );
  KkDiagramPainter(
    geometry: g,
    colors: colors,
    type: const KkTypography(),
    metrics: const KkNodeMetrics(showText: false),
    ground: ground,
  ).paintNodes(canvas);
}
