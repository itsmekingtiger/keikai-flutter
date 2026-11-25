import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../motion/effects.dart';
import '../motion/loops.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/text.dart';
import 'progress.dart';

/// What a region shows when it has nothing to show: a large CJK word, its
/// Latin capitals, one mono line of explanation and, optionally, a scanning
/// bar and an action.
///
/// [KkEmpty.noSignal] is the lost-feed form: a solid offline frame, a title
/// that flickers every 2.4s and CRT noise over the ground.
class KkEmpty extends StatelessWidget {
  const KkEmpty({
    super.key,
    this.cjk,
    this.en,
    this.sub,
    this.loading = false,
    this.action,
    this.minHeight = 168,
    this.padding,
  }) : noSignal = false,
       noise = false;

  /// The feed is gone.
  const KkEmpty.noSignal({
    super.key,
    this.cjk = '無信号',
    this.en = 'NO SIGNAL',
    this.sub,
    this.loading = false,
    this.action,
    this.minHeight = 168,
    this.padding,
    this.noise = true,
  }) : noSignal = true;

  /// The large CJK word: 2 to 6 characters.
  final String? cjk;

  /// Latin capitals under it.
  final String? en;

  /// One mono line of explanation; it may wrap.
  final String? sub;

  /// Show a 160px scanning bar: something is still being fetched.
  final bool loading;

  /// A control under the text, usually a [KkButton].
  final Widget? action;
  final double minHeight;

  /// Defaults to 24 all round.
  final EdgeInsets? padding;
  final bool noSignal;

  /// Draw flickering CRT noise over the ground ([KkEmpty.noSignal] only).
  final bool noise;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final String? cjkText = cjk;
    final String? enText = en;
    final String? subText = sub;
    final Widget? act = action;

    final Widget? title = (cjkText == null || cjkText.isEmpty)
        ? null
        : KkText.cjk(cjkText, size: 36, color: c.inkDim, squeeze: 0.8);

    // The row makes the box as wide as it is allowed to be and centres the
    // text block vertically inside the minimum height.
    Widget body = KkBox(
      minHeight: minHeight,
      padding: padding ?? EdgeInsets.all(m.space6),
      decoration: KkDecoration(
        fill: c.bg000,
        edges: KkEdges.line(noSignal ? c.offline : c.inkFaint, width: m.stroke1, dashed: !noSignal),
      ),
      clip: true,
      child: KkRow(
        children: <Widget>[
          KkExpanded(
            child: KkColumn(
              shrinkWrap: true,
              gap: m.space2,
              cross: KkCrossAlign.center,
              children: <Widget>[
                if (title != null) noSignal ? _FlickerLoop(child: title) : title,
                if (enText != null && enText.isNotEmpty) KkText.en(enText, size: 13, spacing: 0.2, color: c.inkDim),
                if (subText != null && subText.isNotEmpty)
                  KkText.num(
                    subText,
                    size: 11,
                    height: 1.5,
                    color: c.inkFaint,
                    textAlign: TextAlign.center,
                    maxLines: null,
                    softWrap: true,
                  ),
                if (loading) const KkBox(width: 160, child: KkProgress.indeterminate(minWidth: 0)),
                ?act,
              ],
            ),
          ),
        ],
      ),
    );
    if (noSignal && noise) body = KkCrt(scanlines: false, noise: true, child: body);
    return body;
  }
}

/// Replays the boot flicker (0 → .9 → .1 → 1 → .35 → 1) every 2.4s.
class _FlickerLoop extends StatelessWidget {
  const _FlickerLoop({required this.child});

  static const Duration _period = Duration(milliseconds: 2400);
  static const KkKeyframes _frames = KkKeyframes(
    <double>[0, 0.2, 0.3, 0.45, 0.55, 0.7, 1],
    <double>[0, 0.9, 0.1, 1, 0.35, 1, 1],
    steps: 12,
  );

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!KeikaiTheme.motionOf(context)) return child;
    // KkLoop's clock already runs at the theme's time scale.
    return KkLoop(
      builder: (BuildContext context, ValueListenable<Duration> time) => AnimatedBuilder(
        animation: time,
        child: child,
        builder: (BuildContext context, Widget? child) =>
            Opacity(opacity: _frames.transform(kkLoopAt(time.value, _period)), child: child),
      ),
    );
  }
}
