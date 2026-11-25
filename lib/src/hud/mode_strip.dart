import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../motion/loops.dart';
import '../painting/shapes.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';

/// One step of a [KkModeStrip].
@immutable
class KkModeStep {
  const KkModeStep({required this.cjk, this.en, this.level});

  final String cjk;
  final String? en;

  /// Colours this step when it is the current or the target one.
  final KkLevel? level;

  @override
  bool operator ==(Object other) =>
      other is KkModeStep && other.cjk == cjk && other.en == en && other.level == level;

  @override
  int get hashCode => Object.hash(cjk, en, level);
}

/// The operating modes of a system as a chain of arrows: 停止 → 起動 → 運転.
///
/// Steps before [current] are past, the current one is filled, and the
/// [target] (the mode the system is moving to) is outlined and blinks every
/// 0.6s until it is reached.
class KkModeStrip extends StatelessWidget {
  const KkModeStrip({
    super.key,
    required this.steps,
    required this.current,
    this.target,
    this.level,
    this.onStepTap,
    this.height = 54,
    this.head = 12,
    this.gap = 2,
  });

  final List<KkModeStep> steps;

  /// Index of the mode the system is in. A negative index marks none.
  final int current;

  /// Index of the mode being armed, if any.
  final int? target;

  /// Colours the current and target steps (signal without one).
  final KkLevel? level;

  /// Makes steps focusable and pressable; called with the step's index.
  final ValueChanged<int>? onStepTap;
  final double height;

  /// Length of the arrow head (and of the notch it fits into).
  final double head;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return KkRow(
      gap: gap,
      cross: KkCrossAlign.stretch,
      children: <Widget>[
        for (int i = 0; i < steps.length; i++)
          KkExpanded(
            child: _ModeStepView(
              step: steps[i],
              index: i,
              isCurrent: i == current,
              isTarget: target != null && i == target && i != current,
              isPast: i < current,
              level: steps[i].level ?? level,
              height: height,
              head: head,
              onTap: onStepTap,
            ),
          ),
      ],
    );
  }
}

class _ModeStepView extends StatelessWidget {
  const _ModeStepView({
    required this.step,
    required this.index,
    required this.isCurrent,
    required this.isTarget,
    required this.isPast,
    required this.level,
    required this.height,
    required this.head,
    required this.onTap,
  });

  final KkModeStep step;
  final int index;
  final bool isCurrent;
  final bool isTarget;
  final bool isPast;
  final KkLevel? level;
  final double height;
  final double head;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final KkColors c = KeikaiTheme.of(context).colors;
    final Color lv = c.level(level);
    final KkShape shape = KkShape.arrow(head: head, notch: index > 0);
    final String? en = step.en;

    Widget plate(bool focused) => KkPhaseBuilder(
      period: const Duration(milliseconds: 600),
      enabled: isTarget,
      builder: (BuildContext context, int phase, Widget? child) {
        final bool armed = isTarget && phase == 1;
        final bool filled = isCurrent || armed;
        final Color ink = filled
            ? c.onFill
            : isTarget
            ? lv
            : isPast
            ? c.inkDim
            : c.inkFaint;
        return CustomPaint(
          painter: _ModeStepPainter(
            shape: shape,
            fill: filled ? lv : c.bg200,
            bars: isTarget && !armed ? lv : null,
            focus: focused ? c.focus : null,
          ),
          child: KkBox(
            height: height,
            padding: EdgeInsets.only(left: index == 0 ? 14 : 22, right: 24),
            alignment: Alignment.centerLeft,
            clip: true,
            child: KkColumn(
              shrinkWrap: true,
              gap: 4,
              cross: KkCrossAlign.start,
              children: <Widget>[
                KkText.cjk(step.cjk, size: 20, color: ink, squeeze: 0.8),
                if (en != null) KkText.en(en, size: 10, weight: FontWeight.w700, spacing: 0.14, color: ink),
              ],
            ),
          ),
        );
      },
    );

    final String label = <String>[
      step.cjk,
      ?en,
      if (isCurrent) 'current' else if (isTarget) 'target' else if (isPast) 'past',
    ].join(' ');
    final ValueChanged<int>? tap = onTap;
    final Widget view = tap == null
        ? Semantics(label: label, child: ExcludeSemantics(child: plate(false)))
        : KkPressable(
            onPressed: () => tap(index),
            semanticLabel: label,
            selected: isCurrent,
            excludeSemantics: true,
            builder: (BuildContext context, KkStates states) => plate(states.focused),
          );
    // Pointer events only land inside the arrow.
    return KkSurface(shape: shape, child: view);
  }
}

class _ModeStepPainter extends CustomPainter {
  const _ModeStepPainter({required this.shape, required this.fill, required this.bars, required this.focus});

  final KkShape shape;
  final Color fill;

  /// Colour of the 2px bars along the top and bottom of an armed step.
  final Color? bars;
  final Color? focus;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    if (rect.isEmpty) return;
    final Path path = shape.path(rect);
    canvas.drawPath(path, Paint()..color = fill);
    final Color? bar = bars;
    if (bar != null) {
      canvas.save();
      canvas.clipPath(path);
      final Paint paint = Paint()..color = bar;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 2), paint);
      canvas.drawRect(Rect.fromLTWH(0, size.height - 2, size.width, 2), paint);
      canvas.restore();
    }
    final Color? ring = focus;
    if (ring != null) {
      canvas.save();
      canvas.clipPath(path);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = ring,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ModeStepPainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.fill != fill || oldDelegate.bars != bars || oldDelegate.focus != focus;
}
