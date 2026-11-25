import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../layout/scroll.dart';
import '../motion/entrances.dart';
import '../motion/loops.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/frame.dart';
import '../widgets/icon.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';
import 'fill_column.dart';

/// Where a step of a [KkSequence] stands.
enum KkStepStatus {
  /// Finished. The mark is filled and the rail through it is signal.
  done,

  /// In progress. The row is raised and the mark's core blinks.
  active,

  /// Not started.
  pending,

  /// Went wrong. The row sits on the deep alert colour.
  failed,

  /// Left out. Dashed mark, struck-through title.
  skipped;

  /// The default state word.
  String get word => switch (this) {
    KkStepStatus.done => 'DONE',
    KkStepStatus.active => 'ACTIVE',
    KkStepStatus.pending => 'PENDING',
    KkStepStatus.failed => 'FAILED',
    KkStepStatus.skipped => 'SKIPPED',
  };
}

/// One step of a [KkSequence].
@immutable
class KkSequenceStep {
  const KkSequenceStep({
    this.cjk,
    this.en,
    this.note,
    this.status = KkStepStatus.pending,
    this.time,
    this.stateLabel,
  });

  final String? cjk;
  final String? en;

  /// A second line in dim mono.
  final String? note;
  final KkStepStatus status;

  /// A time at the right, such as `14:02:31Z` or `T+00:42`.
  final String? time;

  /// The state word. Defaults to the status' word; an empty string hides it.
  final String? stateLabel;

  @override
  bool operator ==(Object other) =>
      other is KkSequenceStep &&
      other.cjk == cjk &&
      other.en == en &&
      other.note == note &&
      other.status == status &&
      other.time == time &&
      other.stateLabel == stateLabel;

  @override
  int get hashCode => Object.hash(cjk, en, note, status, time, stateLabel);
}

String _two(int v) => v < 10 ? '0$v' : '$v';

/// A procedure as a list of numbered steps on a rail: start-up, shutdown,
/// launch, recovery.
///
/// The head counts the finished steps (`03 / 07`) and a thin bar under it
/// shows the same as a fill. A sequence fills a grid cell and scrolls inside
/// it; on its own it is as tall as its steps.
class KkSequence extends StatelessWidget {
  const KkSequence({
    super.key,
    this.cjk,
    this.en,
    required this.steps,
    this.level,
    this.progress,
    this.count,
    this.showIndex = true,
    this.onStepTap,
    this.minWidth = 300,
    this.boot = true,
  });

  final String? cjk;
  final String? en;
  final List<KkSequenceStep> steps;

  /// Colours the progress bar.
  final KkLevel? level;

  /// Fill of the bar, 0 to 1. Defaults to the share of finished steps.
  final double? progress;

  /// The count at the right of the head. Defaults to `done / total`.
  final String? count;

  /// Show the step numbers.
  final bool showIndex;

  /// Makes steps focusable and pressable; called with the step's index.
  final ValueChanged<int>? onStepTap;
  final double minWidth;

  /// Wipe in when first shown.
  final bool boot;

  /// How many of [steps] are done.
  static int doneCount(List<KkSequenceStep> steps) =>
      steps.where((KkSequenceStep s) => s.status == KkStepStatus.done).length;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final int done = doneCount(steps);
    final double p = progress ?? (steps.isEmpty ? 0 : done / steps.length);
    final Widget sequence = Semantics(
      container: true,
      child: KkBox(
        minWidth: minWidth,
        decoration: KkDecoration(
          fill: c.bg100,
          edges: KkEdges.line(c.line, width: m.stroke1),
        ),
        clip: true,
        child: KkFillColumn(
          leading: <Widget>[
            KkWidgetHead(cjk: cjk, en: en, meta: count ?? '${_two(done)} / ${_two(steps.length)}'),
            KkBox(
              padding: EdgeInsets.symmetric(horizontal: m.space3),
              child: CustomPaint(
                size: Size(0, m.space1),
                painter: _BarPainter(value: p.isNaN ? 0 : p.clamp(0.0, 1.0), track: c.signalDim, fill: c.level(level)),
              ),
            ),
          ],
          body: KkScroll(
            padding: EdgeInsets.symmetric(vertical: m.space2),
            child: KkColumn(
              shrinkWrap: true,
              children: <Widget>[
                for (int i = 0; i < steps.length; i++)
                  _StepRow(
                    step: steps[i],
                    index: i,
                    first: i == 0,
                    last: i == steps.length - 1,
                    showIndex: showIndex,
                    onTap: onStepTap,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return boot ? KkBoot(child: sequence) : sequence;
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.index,
    required this.first,
    required this.last,
    required this.showIndex,
    required this.onTap,
  });

  final KkSequenceStep step;
  final int index;
  final bool first;
  final bool last;
  final bool showIndex;
  final ValueChanged<int>? onTap;

  static const double _indexWidth = 22;
  static const double _markSize = 16;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final KkStepStatus status = step.status;
    final bool active = status == KkStepStatus.active;
    final bool failed = status == KkStepStatus.failed;
    final bool skipped = status == KkStepStatus.skipped;
    final bool muted = status == KkStepStatus.pending || skipped;

    final Color rowInk = (active || failed) ? c.ink : c.inkDim;
    final Color titleInk = muted ? c.inkDim : c.ink;
    final Color indexInk = active
        ? c.signal
        : failed
        ? c.ink
        : c.inkFaint;
    final Color stateInk = active ? c.signal : rowInk;
    final Color dimInk = failed ? c.ink : c.inkDim;
    final Color? rowFill = active
        ? c.bg200
        : failed
        ? c.alertDeep
        : null;
    final TextStyle? strike = skipped ? const TextStyle(decoration: TextDecoration.lineThrough) : null;

    final String? cjk = step.cjk;
    final String? en = step.en;
    final String? note = step.note;
    final String? time = step.time;
    final String word = step.stateLabel ?? status.word;
    final double railLeft = m.space3 + (showIndex ? _indexWidth + m.space3 : 0) + (_markSize - m.stroke2) / 2;

    Widget row(bool focused) => KkFocusRing(
      visible: focused,
      offset: -2,
      child: KkBox(
        fill: rowFill,
        child: CustomPaint(
          painter: _RailPainter(
            left: railLeft,
            width: m.stroke2,
            color: status == KkStepStatus.done ? c.signal : c.line,
            first: first,
            last: last,
          ),
          child: KkBox(
            minHeight: 40,
            padding: EdgeInsets.symmetric(horizontal: m.space3),
            child: KkRow(
              gap: m.space3,
              children: <Widget>[
                if (showIndex)
                  KkBox(
                    width: _indexWidth,
                    child: KkText.num(_two(index + 1), size: 11, weight: FontWeight.w500, color: indexInk),
                  ),
                _mark(c, m, status),
                KkExpanded(
                  child: KkBox(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: KkColumn(
                      gap: 3,
                      shrinkWrap: true,
                      children: <Widget>[
                        KkRow(
                          gap: m.space2,
                          cross: KkCrossAlign.baseline,
                          clip: Clip.hardEdge,
                          children: <Widget>[
                            if (cjk != null)
                              KkText.cjk(cjk, size: 14, height: 1.55, color: titleInk, squeeze: 0.8, style: strike),
                            if (en != null)
                              KkText.en(
                                en,
                                size: 12,
                                weight: FontWeight.w600,
                                height: 1.55,
                                spacing: 0.1,
                                color: rowInk,
                                style: strike,
                              ),
                          ],
                        ),
                        if (note != null)
                          KkText.num(note, size: 11, height: 1.3, color: dimInk, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
                if (word.isNotEmpty)
                  KkText.en(word, size: 10, weight: FontWeight.w700, spacing: 0.16, color: stateInk),
                if (time != null) KkText.num(time, size: 11, color: dimInk),
              ],
            ),
          ),
        ),
      ),
    );

    final String label = <String>[
      _two(index + 1),
      ?cjk,
      ?en,
      word.isEmpty ? status.word : word,
      ?note,
      ?time,
    ].join(' ');
    final ValueChanged<int>? tap = onTap;
    if (tap == null) return Semantics(label: label, child: ExcludeSemantics(child: row(false)));
    return KkPressable(
      onPressed: () => tap(index),
      semanticLabel: label,
      excludeSemantics: true,
      builder: (BuildContext context, KkStates states) => row(states.focused),
    );
  }

  Widget _mark(KkColors c, KkMetrics m, KkStepStatus status) {
    KkBox plate({required Color edge, Color? fill, bool dashed = false, Widget? child}) => KkBox(
      width: _markSize,
      height: _markSize,
      alignment: Alignment.center,
      decoration: KkDecoration(
        fill: fill ?? c.bg100,
        edges: KkEdges.line(edge, width: m.stroke2, dashed: dashed),
      ),
      child: child,
    );
    return switch (status) {
      KkStepStatus.done => plate(
        edge: c.signal,
        fill: c.signal,
        child: KkIcon(KkIcons.check, size: 12, color: c.onFill),
      ),
      KkStepStatus.active => plate(
        edge: c.signal,
        child: KkBlink(child: KkBox(width: 6, height: 6, fill: c.signal)),
      ),
      KkStepStatus.pending => plate(edge: c.inkFaint),
      KkStepStatus.failed => KkIcon(KkIcons.statusCritical, size: _markSize, color: c.ink),
      KkStepStatus.skipped => plate(edge: c.inkFaint, dashed: true),
    };
  }
}

class _RailPainter extends CustomPainter {
  const _RailPainter({
    required this.left,
    required this.width,
    required this.color,
    required this.first,
    required this.last,
  });

  final double left;
  final double width;
  final Color color;
  final bool first;
  final bool last;

  @override
  void paint(Canvas canvas, Size size) {
    final double top = first ? size.height / 2 : 0;
    final double bottom = last ? size.height / 2 : size.height;
    if (bottom <= top) return;
    canvas.drawRect(Rect.fromLTRB(left, top, left + width, bottom), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RailPainter oldDelegate) =>
      oldDelegate.left != left ||
      oldDelegate.width != width ||
      oldDelegate.color != color ||
      oldDelegate.first != first ||
      oldDelegate.last != last;
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
    final double w = size.width * value;
    if (w > 0) canvas.drawRect(Rect.fromLTWH(0, 0, w, size.height), Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_BarPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.track != track || oldDelegate.fill != fill;
}
