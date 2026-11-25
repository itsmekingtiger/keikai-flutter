import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../charts/sparkline.dart';
import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../hud/state_word.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../widgets/icon.dart';
import '../widgets/text.dart';

/// What a cell can know about the row it is in.
///
/// [KkDataTable] puts one around every body row. The ready-made cell kinds
/// read it to follow the row's density and to switch to ink on a critical
/// row, where the row's ground is the dark alarm fill.
class KkTableRowScope extends InheritedWidget {
  const KkTableRowScope({super.key, this.level, this.dense = false, this.selected = false, required super.child});

  /// The row's level, from `KkDataTable.rowLevel`.
  final KkLevel? level;

  /// The table is in its dense form (24px rows, 11px type).
  final bool dense;
  final bool selected;

  /// The row is on the alarm ground: everything on it is drawn in ink.
  bool get critical => level == KkLevel.critical;

  /// The nearest row scope, or null outside a table row.
  static KkTableRowScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KkTableRowScope>();

  @override
  bool updateShouldNotify(KkTableRowScope oldWidget) =>
      oldWidget.level != level || oldWidget.dense != dense || oldWidget.selected != selected;
}

/// A level said in a cell: the status icon and the status word in the level's
/// colour. Without a [level] it takes the row's; without either it is `INFO`
/// in dim ink.
class KkTableLevel extends StatelessWidget {
  const KkTableLevel({super.key, this.level, this.text, this.showGlyph = true});

  final KkLevel? level;

  /// The word. Defaults to the level's word.
  final String? text;
  final bool showGlyph;

  @override
  Widget build(BuildContext context) {
    final KkTableRowScope? row = KkTableRowScope.maybeOf(context);
    final KkLevel? lv = level ?? row?.level;
    return KkStateWord(
      level: lv,
      text: text,
      color: (row?.critical ?? false) ? KeikaiTheme.of(context).colors.ink : null,
      size: 11,
      glyphSize: 10,
      gap: 6,
      weight: FontWeight.w700,
      spacing: 0.12,
      showGlyph: showGlyph,
    );
  }
}

/// An identifier in a cell: mono text in signal (`SEC-04`, `P-0117`).
class KkTableCode extends StatelessWidget {
  const KkTableCode(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final KkColors c = KeikaiTheme.of(context).colors;
    final bool critical = KkTableRowScope.maybeOf(context)?.critical ?? false;
    return KkText(
      text,
      color: critical ? c.ink : c.signal,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// A value in a cell that can carry a level: the text turns the level's
/// colour and semibold, and caution, critical and offline put their status
/// icon before it. Nominal and plain values keep the icon's place empty, so a
/// column of values stays aligned.
class KkTableValue extends StatelessWidget {
  const KkTableValue(this.text, {super.key, this.level, this.reserveGlyph = true});

  final String text;
  final KkLevel? level;

  /// Keep the icon's place when there is no icon to show.
  final bool reserveGlyph;

  @override
  Widget build(BuildContext context) {
    final KkColors c = KeikaiTheme.of(context).colors;
    final bool critical = KkTableRowScope.maybeOf(context)?.critical ?? false;
    final KkLevel? lv = level;
    final Color? ink = critical ? c.ink : (lv != null ? c.level(lv) : null);
    final bool flagged = lv != null && lv != KkLevel.nominal;
    return KkRow(
      shrinkWrap: true,
      gap: 4,
      children: <Widget>[
        if (flagged) KkGlyph(level: lv, size: 10, color: ink) else if (reserveGlyph) const KkBox(width: 10, height: 10),
        KkText(
          text,
          color: ink,
          style: lv != null ? const TextStyle(fontWeight: FontWeight.w600) : null,
          maxLines: 1,
          softWrap: false,
        ),
      ],
    );
  }
}

/// A 72 × 6 bar in a cell: [value] (0 to 1) of the track is lit, in signal or
/// in the [level]'s colour.
class KkTableBar extends StatelessWidget {
  const KkTableBar(this.value, {super.key, this.level, this.width = 72, this.height = 6, this.semanticLabel});

  /// 0 to 1. Values outside are clamped; NaN is empty.
  final double value;
  final KkLevel? level;
  final double width;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final KkColors c = KeikaiTheme.of(context).colors;
    final bool critical = KkTableRowScope.maybeOf(context)?.critical ?? false;
    final double v = value.isNaN ? 0 : value.clamp(0.0, 1.0);
    final Widget bar = CustomPaint(
      size: Size(width, height),
      painter: _BarPainter(
        value: v,
        track: critical ? kkMix(c.ink, 0.25, c.alertDeep) : c.signalDim,
        fill: critical ? c.ink : c.level(level),
      ),
    );
    return Semantics(
      label: semanticLabel,
      value: '${(v * 100).round()}%',
      child: ExcludeSemantics(child: bar),
    );
  }
}

class _BarPainter extends CustomPainter {
  const _BarPainter({required this.value, required this.track, required this.fill});

  final double value;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawRect(Offset.zero & size, Paint()..color = track);
    if (value > 0) canvas.drawRect(Rect.fromLTWH(0, 0, size.width * value, size.height), Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_BarPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.track != track || oldDelegate.fill != fill;
}

/// A segmented meter in a cell: 5 × 10 segments 1px apart, lit up to [value]
/// (0 to 1), and the percentage after them.
///
/// A segment lights only when the value has reached it, so the last one is on
/// at 100% and not before.
class KkTableMeter extends StatelessWidget {
  const KkTableMeter(
    this.value, {
    super.key,
    this.segments = 10,
    this.level,
    this.showPercent = true,
    this.label,
    this.semanticLabel,
  }) : assert(segments > 0);

  /// 0 to 1. Values outside are clamped; NaN is empty and reads `--`.
  final double value;
  final int segments;
  final KkLevel? level;
  final bool showPercent;

  /// Replaces the percentage text.
  final String? label;
  final String? semanticLabel;

  /// How many of [segments] segments are lit at [value].
  static int litSegments(double value, int segments) {
    if (value.isNaN) return 0;
    return math.min(segments, math.max(0, (value.clamp(0.0, 1.0) * segments + 1e-9).floor()));
  }

  @override
  Widget build(BuildContext context) {
    final KkColors c = KeikaiTheme.of(context).colors;
    final bool critical = KkTableRowScope.maybeOf(context)?.critical ?? false;
    final String text = label ?? (value.isNaN ? '--' : '${(value.clamp(0.0, 1.0) * 100).round()}%');
    final Widget meter = KkRow(
      shrinkWrap: true,
      gap: 6,
      children: <Widget>[
        CustomPaint(
          size: Size(segments * 5.0 + (segments - 1) * 1.0, 10),
          painter: _SegmentsPainter(
            count: segments,
            lit: litSegments(value, segments),
            off: critical ? kkMix(c.ink, 0.22, c.alertDeep) : c.signalDim,
            on: critical ? c.ink : c.level(level),
          ),
        ),
        if (showPercent)
          // min-width: 4ch of the 11px mono face, right-aligned.
          KkBox(
            minWidth: 4 * 11 * 0.6 * KeikaiTheme.of(context).type.scale,
            alignment: Alignment.centerRight,
            shrinkWrap: true,
            child: KkText.num(text, size: 11, color: critical ? c.ink : c.inkDim),
          ),
      ],
    );
    return Semantics(
      label: semanticLabel,
      value: text,
      child: ExcludeSemantics(child: meter),
    );
  }
}

class _SegmentsPainter extends CustomPainter {
  const _SegmentsPainter({required this.count, required this.lit, required this.off, required this.on});

  final int count;
  final int lit;
  final Color off;
  final Color on;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();
    for (int i = 0; i < count; i++) {
      canvas.drawRect(Rect.fromLTWH(i * 6.0, 0, 5, size.height), paint..color = i < lit ? on : off);
    }
  }

  @override
  bool shouldRepaint(_SegmentsPainter oldDelegate) =>
      oldDelegate.count != count || oldDelegate.lit != lit || oldDelegate.off != off || oldDelegate.on != on;
}

/// An 80 × 18 sparkline in a cell. On a critical row the line is ink.
class KkTableSpark extends StatelessWidget {
  const KkTableSpark(
    this.values, {
    super.key,
    this.level,
    this.color,
    this.width = 80,
    this.height = 18,
    this.area = true,
    this.dot = true,
    this.reference,
    this.animate = true,
    this.semanticLabel,
  });

  /// The values, oldest first. Null and non-finite values are gaps.
  final List<double?> values;
  final KkLevel? level;

  /// Defaults to the level colour, or series-1.
  final Color? color;
  final double width;
  final double height;
  final bool area;
  final bool dot;
  final double? reference;
  final bool animate;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool critical = KkTableRowScope.maybeOf(context)?.critical ?? false;
    return KkSparkline(
      values: values,
      color: critical ? KeikaiTheme.of(context).colors.ink : color,
      level: level,
      width: width,
      height: height,
      area: area,
      dot: dot,
      reference: reference,
      animate: animate,
      semanticLabel: semanticLabel,
    );
  }
}

/// One cell of the summary row: a small key (`AVG`, `MAX`) before a value.
///
/// [KkTableSummary.title] is the label cell that names the row: a CJK word
/// and Latin capitals.
class KkTableSummary extends StatelessWidget {
  /// A value with an optional key before it.
  const KkTableSummary(String this.value, {super.key, this.label, this.level}) : cjk = null, en = null;

  /// The cell that names the summary row (合計 TOTAL).
  const KkTableSummary.title({super.key, this.cjk, this.en}) : value = null, label = null, level = null;

  /// The summarised value, in mono.
  final String? value;

  /// The small key before the value; shown in capitals.
  final String? label;

  /// Colours the value.
  final KkLevel? level;
  final String? cjk;
  final String? en;

  @override
  Widget build(BuildContext context) {
    final KkColors c = KeikaiTheme.of(context).colors;
    final String? v = value;
    if (v == null) {
      final String? cjkText = cjk;
      final String? enText = en;
      return KkRow(
        shrinkWrap: true,
        cross: KkCrossAlign.baseline,
        gap: 6,
        clip: Clip.hardEdge,
        children: <Widget>[
          if (cjkText != null && cjkText.isNotEmpty) KkText.cjk(cjkText, size: 13, color: c.ink, squeeze: 0.8),
          if (enText != null && enText.isNotEmpty)
            KkText.en(enText, size: 10, weight: FontWeight.w700, spacing: 0.14, color: c.inkDim),
        ],
      );
    }
    final String? key = label;
    return KkRow(
      shrinkWrap: true,
      cross: KkCrossAlign.baseline,
      gap: 6,
      clip: Clip.hardEdge,
      children: <Widget>[
        if (key != null && key.isNotEmpty)
          KkText.en(key, size: 9, weight: FontWeight.w700, spacing: 0.14, color: c.inkDim),
        KkText.num(v, size: 12, weight: FontWeight.w500, color: level != null ? c.level(level) : c.ink),
      ],
    );
  }
}
