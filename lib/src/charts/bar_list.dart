import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../layout/layers.dart';
import '../motion/entrances.dart';
import '../widgets/icon.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';
import 'plot.dart';
import 'series.dart';

/// One row of a [KkBarList].
@immutable
class KkBarListItem {
  const KkBarListItem({this.cjk, this.en, required this.value, this.level, this.display, this.unit});

  /// CJK name, written inside the bar.
  final String? cjk;

  /// Latin name (capitals), written inside the bar.
  final String? en;
  final double value;

  /// Colours the bar and adds the status icon before the name.
  final KkLevel? level;

  /// The value as shown. Defaults to the list's formatter.
  final String? display;

  /// Small unit after the value. Defaults to the list's unit.
  final String? unit;
}

/// A ranked list of horizontal bars: rank, a 24px track with the name written
/// on it, and the value at the right. The top talkers, the busiest sectors.
///
/// The fill is the series colour at 30% with a solid 2px leading edge; a row
/// with a level takes the level colour at 26%. Fills grow from the left on
/// entry (0.5s in 10 steps, 40ms apart).
class KkBarList extends StatelessWidget {
  const KkBarList({
    super.key,
    required this.items,
    this.max,
    this.unit,
    this.format,
    this.showRank = true,
    this.rankWidth = 20,
    this.valueWidth = 64,
    this.rowHeight = 24,
    this.color,
    this.frame = true,
    this.cjk,
    this.en,
    this.meta,
    this.onItemTap,
    this.animate = true,
    this.boot = true,
    this.semanticLabel,
  });

  final List<KkBarListItem> items;

  /// The value of a full bar. Defaults to the largest value in [items].
  final double? max;

  /// Small unit after every value.
  final String? unit;

  /// Formats a value. Defaults to a whole number.
  final String Function(double value)? format;

  /// Show the rank column (`01`, `02` …).
  final bool showRank;
  final double rankWidth;

  /// Width of the value column.
  final double valueWidth;
  final double rowHeight;

  /// Bar colour for rows without a level. Defaults to series-1.
  final Color? color;

  /// Draw the widget frame and head. False leaves the list bare.
  final bool frame;
  final String? cjk;
  final String? en;
  final String? meta;
  final ValueChanged<int>? onItemTap;

  /// Play the grow-in when first shown.
  final bool animate;

  /// Play the frame's boot wipe when first shown.
  final bool boot;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    double top = 0;
    for (final KkBarListItem item in items) {
      if (item.value.isFinite) top = math.max(top, item.value);
    }
    final double? given = max;
    final double full = (given != null && given.isFinite && given > 0) ? given : top;
    final KkCascade cascade = KkCascade(
      count: items.length,
      item: KkMotion.barGrow,
      step: const Duration(milliseconds: 40),
    );

    String text(KkBarListItem item) {
      if (item.display != null) return item.display!;
      if (!item.value.isFinite) return '--';
      return format?.call(item.value) ?? item.value.round().toString();
    }

    final Widget list = KkOneShot(
      duration: cascade.total,
      delay: const Duration(milliseconds: 200),
      enabled: animate,
      builder: (BuildContext context, Animation<double> progress, bool done, Widget? _) {
        return KkColumn(
          gap: 6,
          shrinkWrap: true,
          children: <Widget>[
            for (int i = 0; i < items.length; i++)
              _BarListRow(
                item: items[i],
                index: i,
                fraction: (full > 0 && items[i].value.isFinite) ? (items[i].value / full).clamp(0.0, 1.0) : 0,
                valueText: text(items[i]),
                unit: items[i].unit ?? unit,
                showRank: showRank,
                rankWidth: rankWidth,
                valueWidth: valueWidth,
                rowHeight: rowHeight,
                color: color ?? c.series1,
                cascade: cascade,
                progress: progress,
                onTap: onItemTap == null ? null : () => onItemTap!(i),
              ),
          ],
        );
      },
    );

    final String summary = <String>[
      for (final KkBarListItem item in items) '${item.en ?? item.cjk ?? ''} ${text(item)}${item.unit ?? unit ?? ''}',
    ].join(', ');
    return KkChartFrame(
      frame: frame,
      cjk: cjk,
      en: en,
      meta: meta,
      boot: boot,
      semanticLabel: semanticLabel,
      semanticValue: items.isEmpty ? 'no data' : summary,
      child: frame ? KkBox(padding: EdgeInsets.all(theme.metrics.space3), clip: true, child: list) : list,
    );
  }
}

class _BarListRow extends StatelessWidget {
  const _BarListRow({
    required this.item,
    required this.index,
    required this.fraction,
    required this.valueText,
    required this.unit,
    required this.showRank,
    required this.rankWidth,
    required this.valueWidth,
    required this.rowHeight,
    required this.color,
    required this.cascade,
    required this.progress,
    required this.onTap,
  });

  final KkBarListItem item;
  final int index;
  final double fraction;
  final String valueText;
  final String? unit;
  final bool showRank;
  final double rankWidth;
  final double valueWidth;
  final double rowHeight;
  final Color color;
  final KkCascade cascade;
  final Animation<double> progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkLevel? level = item.level;
    final Color edge = level == null ? color : c.level(level);
    final Color fill = kkMix(edge, level == null ? 0.30 : 0.26, c.bg200);
    final String? u = unit;

    final Widget track = KkBox(
      height: rowHeight,
      fill: c.bg200,
      clip: true,
      child: KkLayers(
        expand: true,
        children: <Widget>[
          KkPositioned.fill(
            child: CustomPaint(
              painter: _FillPainter(
                fraction: fraction,
                fill: fill,
                edge: edge,
                edgeWidth: theme.metrics.stroke2,
                index: index,
                cascade: cascade,
                progress: progress,
              ),
            ),
          ),
          KkBox(
            padding: EdgeInsets.symmetric(horizontal: theme.metrics.space2),
            alignment: Alignment.centerLeft,
            child: KkRow(
              shrinkWrap: true,
              gap: 6,
              clip: Clip.hardEdge,
              children: <Widget>[
                if (level != null) KkGlyph(level: level, size: 10),
                if (item.cjk != null) KkText.cjk(item.cjk!, size: 13, color: c.ink, squeeze: 0.8),
                if (item.en != null)
                  KkText.en(item.en!, size: 12, weight: FontWeight.w600, spacing: 0.06, color: c.ink),
              ],
            ),
          ),
        ],
      ),
    );

    final Widget row = KkRow(
      gap: theme.metrics.space2,
      children: <Widget>[
        if (showRank)
          KkBox(
            width: rankWidth,
            alignment: Alignment.centerLeft,
            child: KkText.num('${index + 1}'.padLeft(2, '0'), size: 10, weight: FontWeight.w500, color: c.inkFaint),
          ),
        KkExpanded(child: track),
        KkBox(
          width: valueWidth,
          alignment: Alignment.centerRight,
          child: KkRow(
            shrinkWrap: true,
            cross: KkCrossAlign.baseline,
            children: <Widget>[
              KkText.num(valueText, size: 13, weight: FontWeight.w500, color: c.ink),
              if (u != null && u.isNotEmpty)
                KkBox(
                  padding: const EdgeInsets.only(left: 2),
                  child: KkText.num(u, size: 10, weight: FontWeight.w500, color: c.inkDim),
                ),
            ],
          ),
        ),
      ],
    );
    if (onTap == null) return row;
    return KkPressable(
      onPressed: onTap,
      semanticLabel: '${item.en ?? item.cjk ?? ''} $valueText${u ?? ''}',
      excludeSemantics: true,
      builder: (BuildContext context, KkStates states) => KkFocusRing(visible: states.focused, child: row),
    );
  }
}

class _FillPainter extends CustomPainter {
  _FillPainter({
    required this.fraction,
    required this.fill,
    required this.edge,
    required this.edgeWidth,
    required this.index,
    required this.cascade,
    required this.progress,
  }) : super(repaint: progress);

  final double fraction;
  final Color fill;
  final Color edge;
  final double edgeWidth;
  final int index;
  final KkCascade cascade;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final double t = cascade.at(progress.value, index, steps: KkMotion.barGrowSteps);
    final double width = size.width * fraction * t;
    if (width <= 0) return;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, size.height), Paint()..color = fill);
    final double e = math.min(edgeWidth, width);
    canvas.drawRect(Rect.fromLTWH(width - e, 0, e, size.height), Paint()..color = edge);
  }

  @override
  bool shouldRepaint(_FillPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.fill != fill ||
      oldDelegate.edge != edge ||
      oldDelegate.edgeWidth != edgeWidth ||
      oldDelegate.index != index ||
      oldDelegate.progress != progress ||
      oldDelegate.cascade.count != cascade.count;
}
