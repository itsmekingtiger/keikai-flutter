import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../layout/box.dart';
import '../painting/shapes.dart';
import '../widgets/frame.dart';
import 'force_layout.dart';
import 'layout.dart';
import 'manual_layout.dart';
import 'metrics.dart';
import 'model.dart';
import 'painter.dart';
import 'router.dart';
import 'view.dart';

/// A network map in a HUD frame: head band with a bilingual title, the node
/// graph, and a legend.
///
/// Nodes are hubs, plates and leaves joined by wires that turn only at 45°.
/// A wire can be active (signal colour), carry flow marks that run along it,
/// or take a level; a node shows its level by colour and status flag, and a
/// critical node blinks a halo. Tap a node to select it and read its plate.
///
/// When every node carries a `position` the graph is drawn where you put it;
/// otherwise it is arranged by the force layout.
class KkNodeGraph extends StatelessWidget {
  const KkNodeGraph({
    super.key,
    required this.diagram,
    this.cjk,
    this.en,
    this.meta,
    this.trailing,
    this.level,
    this.layout,
    this.router = const KkEdgeRouter.octilinear(),
    this.metrics = const KkNodeMetrics(),
    this.padding = const EdgeInsets.all(16),
    this.legend = true,
    this.footer,
    this.expand = false,
    this.height,
    this.minWidth = 320,
    this.interactive = false,
    this.controller,
    this.selectable = true,
    this.selected,
    this.onSelected,
    this.onNodeTap,
    this.showInfo = true,
    this.infoBuilder,
    this.arrows = false,
    this.animate = true,
  });

  final KkDiagram diagram;

  /// CJK title of the head band.
  final String? cjk;

  /// Latin capitals subtitle of the head band.
  final String? en;

  /// Mono text at the right of the head band, such as a node count.
  final String? meta;

  /// A widget at the right of the head band.
  final Widget? trailing;

  /// Level of the whole widget: critical turns the frame red and makes it
  /// glow, offline dashes it.
  final KkLevel? level;

  /// Defaults to a manual layout when every node has a position, else to the
  /// force layout.
  final KkDiagramLayout? layout;
  final KkEdgeRouter router;
  final KkNodeMetrics metrics;
  final EdgeInsets padding;

  /// Show a legend of the symbols and wire styles that are in the diagram.
  final bool legend;

  /// Extra entries for the foot band, after the legend.
  final List<Widget>? footer;

  /// Let the plot take all the height the parent gives (inside a grid cell).
  final bool expand;

  /// A fixed height for the plot.
  final double? height;
  final double minWidth;

  /// Let the user drag and zoom the plot.
  final bool interactive;
  final KkDiagramController? controller;
  final bool selectable;
  final String? selected;
  final ValueChanged<String?>? onSelected;
  final ValueChanged<KkDiagramNode>? onNodeTap;
  final bool showInfo;
  final List<String> Function(KkDiagramNode node)? infoBuilder;

  /// Draw arrow heads. A network map normally shows direction by flow marks
  /// instead.
  final bool arrows;
  final bool animate;

  KkDiagramLayout get _layout {
    final KkDiagramLayout? given = layout;
    if (given != null) return given;
    final bool placed = diagram.nodes.isNotEmpty && diagram.nodes.every((KkDiagramNode n) => n.position != null);
    return placed ? const KkManualLayout() : const KkForceLayout();
  }

  List<Widget> _legend(KkColors c) {
    final Set<KkNodeKind> kinds = <KkNodeKind>{for (final KkDiagramNode n in diagram.nodes) n.kind};
    final bool active = diagram.edges.any((KkDiagramEdge e) => e.active);
    final bool flow = diagram.edges.any((KkDiagramEdge e) => e.flow != KkEdgeFlow.none);
    final bool offline =
        diagram.edges.any((KkDiagramEdge e) => e.level == KkLevel.offline) ||
        diagram.nodes.any((KkDiagramNode n) => n.level == KkLevel.offline);
    return <Widget>[
      for (final KkNodeKind kind in KkNodeKind.values)
        if (kinds.contains(kind))
          KkWidgetKey(
            label: kind.name.toUpperCase(),
            swatch: KkNodeSymbol(kind: kind),
          ),
      if (active) KkWidgetKey(label: 'ACTIVE', color: c.signal),
      if (flow) const KkWidgetKey(label: 'FLOW', swatch: _WireSwatch(flow: true)),
      if (offline) const KkWidgetKey(label: 'OFFLINE', swatch: _WireSwatch(flow: false)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final KkColors c = KeikaiTheme.of(context).colors;
    Widget plot = KkDiagramView(
      diagram: diagram,
      layout: _layout,
      router: router,
      metrics: metrics,
      padding: padding,
      interactive: interactive,
      controller: controller,
      selectable: selectable,
      selected: selected,
      onSelected: onSelected,
      onNodeTap: onNodeTap,
      showInfo: showInfo,
      infoBuilder: infoBuilder,
      arrows: arrows,
      ground: c.bg100,
      animate: animate,
      semanticLabel: <String?>[cjk, en].whereType<String>().join(' ').trim().isEmpty
          ? null
          : '${<String?>[cjk, en].whereType<String>().join(' ')}, ${diagram.nodes.length} nodes',
    );
    if (height != null) plot = KkBox(height: height, child: plot);
    final List<Widget> foot = <Widget>[if (legend) ..._legend(c), ...?footer];
    return KkBox(
      minWidth: minWidth,
      child: KkWidgetFrame(
        cjk: cjk,
        en: en,
        meta: meta,
        trailing: trailing,
        level: level,
        footer: foot.isEmpty ? null : foot,
        expandBody: expand,
        boot: animate,
        child: plot,
      ),
    );
  }
}

/// One node symbol drawn the way a diagram draws it, for legends and lists.
class KkNodeSymbol extends StatelessWidget {
  const KkNodeSymbol({super.key, required this.kind, this.level, this.size = 12});

  final KkNodeKind kind;
  final KkLevel? level;

  /// Height of the symbol; the width follows the kind's proportions.
  final double size;

  @override
  Widget build(BuildContext context) {
    final KkColors c = KeikaiTheme.of(context).colors;
    final double width = switch (kind) {
      KkNodeKind.terminal => size * 2,
      KkNodeKind.leaf => size * 0.75,
      _ => size,
    };
    final double height = kind == KkNodeKind.leaf ? size * 0.75 : size;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(width, size),
        painter: _SymbolPainter(kind, level, c, height),
      ),
    );
  }
}

class _SymbolPainter extends CustomPainter {
  _SymbolPainter(this.kind, this.level, this.colors, this.height);

  final KkNodeKind kind;
  final KkLevel? level;
  final KkColors colors;
  final double height;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromCenter(center: size.center(Offset.zero), width: size.width, height: height).deflate(0.75);
    kkPaintNodeSymbol(canvas, rect, kind, colors: colors, level: level);
  }

  @override
  bool shouldRepaint(_SymbolPainter old) =>
      old.kind != kind || old.level != level || old.colors != colors || old.height != height;
}

class _WireSwatch extends StatelessWidget {
  const _WireSwatch({required this.flow});

  /// Flow marks on a live wire, or the dashes of an offline one.
  final bool flow;

  @override
  Widget build(BuildContext context) {
    final KkColors c = KeikaiTheme.of(context).colors;
    return ExcludeSemantics(
      child: CustomPaint(size: const Size(20, 6), painter: _WireSwatchPainter(flow, c)),
    );
  }
}

class _WireSwatchPainter extends CustomPainter {
  _WireSwatchPainter(this.flow, this.colors);

  final bool flow;
  final KkColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final double y = size.height / 2;
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = flow ? colors.signal : colors.offline;
    final Path wire = Path()
      ..moveTo(0, y)
      ..lineTo(size.width, y);
    canvas.drawPath(flow ? wire : kkDashPath(wire, const <double>[3, 4]), line);
    if (flow) {
      final Paint mark = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.square
        ..strokeWidth = 3
        ..color = colors.signal;
      for (double x = 3; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(x + 2, y), mark);
      }
    }
  }

  @override
  bool shouldRepaint(_WireSwatchPainter old) => old.flow != flow || old.colors != colors;
}
