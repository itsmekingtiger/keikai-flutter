import 'package:flutter/widgets.dart';

import '../foundation/icons.dart';
import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../painting/shapes.dart';
import '../painting/svg_path.dart';

final Map<String, Path> _strokeCache = <String, Path>{};
final Map<String, Path> _fillCache = <String, Path>{};
final Map<String, Path> _dashCache = <String, Path>{};

/// Paints [icon] into [rect] in [color]. The icon grid is 16×16; the 1.5px
/// line scales with the rect.
void kkPaintIcon(Canvas canvas, Rect rect, KkIconData icon, Color color) {
  if (rect.isEmpty || color.a <= 0) return;
  canvas.save();
  canvas.translate(rect.left, rect.top);
  canvas.scale(rect.width / 16, rect.height / 16);
  if (icon.fill.isNotEmpty) {
    final Path p = _fillCache[icon.fill] ??= kkParseSvgPath(icon.fill)..fillType = PathFillType.evenOdd;
    canvas.drawPath(p, Paint()..color = color);
  }
  if (icon.stroke.isNotEmpty || icon.dashed.isNotEmpty) {
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter
      ..color = color;
    if (icon.stroke.isNotEmpty) {
      canvas.drawPath(_strokeCache[icon.stroke] ??= kkParseSvgPath(icon.stroke), line);
    }
    if (icon.dashed.isNotEmpty) {
      final Path p = _dashCache[icon.dashed] ??= kkDashPath(kkParseSvgPath(icon.dashed), const <double>[2.6, 1.9]);
      canvas.drawPath(p, line..strokeCap = StrokeCap.butt);
    }
  }
  canvas.restore();
}

/// The status icon for [level]: a plate cut at the top left with a mark.
/// Critical is the only filled plate and offline the only dashed one, so the
/// level reads without colour.
KkIconData kkStatusIcon(KkLevel? level) => switch (level) {
  KkLevel.nominal => KkIcons.statusNominal,
  KkLevel.caution => KkIcons.statusCaution,
  KkLevel.critical => KkIcons.statusCritical,
  KkLevel.offline => KkIcons.statusOffline,
  null => KkIcons.statusInfo,
};

/// Draws one icon of the KEIKAI set.
///
/// The colour defaults to the current text colour, so an icon inside a button
/// or a tag takes that component's ink.
class KkIcon extends StatelessWidget {
  const KkIcon(this.icon, {super.key, this.size = 16, this.color, this.semanticLabel});

  final KkIconData icon;
  final double size;
  final Color? color;

  /// Announced by screen readers; without it the icon is decorative.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? DefaultTextStyle.of(context).style.color ?? KeikaiTheme.of(context).colors.ink;
    final Widget leaf = _KkIconLeaf(icon: icon, size: size, color: c);
    if (semanticLabel == null) return ExcludeSemantics(child: leaf);
    return Semantics(label: semanticLabel, image: true, child: leaf);
  }
}

/// The status icon of a level, coloured by that level.
///
/// With [color] null the glyph takes the level's colour; a null [level] shows
/// the info plate in the current text colour.
class KkGlyph extends StatelessWidget {
  const KkGlyph({super.key, this.level, this.size = 12, this.color});

  final KkLevel? level;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final Color c =
        color ??
        (level != null ? theme.colors.level(level) : (DefaultTextStyle.of(context).style.color ?? theme.colors.inkDim));
    return ExcludeSemantics(
      child: _KkIconLeaf(icon: kkStatusIcon(level), size: size, color: c),
    );
  }
}

class _KkIconLeaf extends LeafRenderObjectWidget {
  const _KkIconLeaf({required this.icon, required this.size, required this.color});

  final KkIconData icon;
  final double size;
  final Color color;

  @override
  RenderKkIcon createRenderObject(BuildContext context) => RenderKkIcon(icon: icon, extent: size, color: color);

  @override
  void updateRenderObject(BuildContext context, RenderKkIcon renderObject) {
    renderObject
      ..icon = icon
      ..extent = size
      ..color = color;
  }
}

/// The render object behind [KkIcon] and [KkGlyph].
class RenderKkIcon extends RenderBox {
  RenderKkIcon({required KkIconData icon, required double extent, required Color color})
    : _icon = icon,
      _extent = extent,
      _color = color;

  KkIconData _icon;
  KkIconData get icon => _icon;
  set icon(KkIconData value) {
    if (value == _icon) return;
    _icon = value;
    markNeedsPaint();
  }

  double _extent;
  double get extent => _extent;
  set extent(double value) {
    if (value == _extent) return;
    _extent = value;
    markNeedsLayout();
  }

  Color _color;
  Color get color => _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  @override
  double computeMinIntrinsicWidth(double height) => _extent;

  @override
  double computeMaxIntrinsicWidth(double height) => _extent;

  @override
  double computeMinIntrinsicHeight(double width) => _extent;

  @override
  double computeMaxIntrinsicHeight(double width) => _extent;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(Size.square(_extent));

  @override
  void performLayout() => size = constraints.constrain(Size.square(_extent));

  @override
  void paint(PaintingContext context, Offset offset) {
    final double s = size.shortestSide;
    final Rect rect = Rect.fromLTWH(offset.dx + (size.width - s) / 2, offset.dy + (size.height - s) / 2, s, s);
    kkPaintIcon(context.canvas, rect, _icon, _color);
  }
}
