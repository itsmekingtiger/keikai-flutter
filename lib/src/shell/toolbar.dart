import 'package:flutter/widgets.dart';

import '../controls/kbd.dart';
import '../foundation/colors.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/text.dart';

/// The bar along the bottom of a screen: a few small controls, the keyboard
/// hints of the view, and a status line at the right.
///
/// 32px high on the panel colour with a 2px line over it. Fill the slots
/// ([leading], [hints], [status], [trailing]) or pass [children] to lay the
/// row out yourself (use `KkSpacer` to push things apart). Whatever does not
/// fit is cut off; the bar never wraps.
class KkToolbar extends StatelessWidget {
  const KkToolbar({
    super.key,
    this.leading = const <Widget>[],
    this.hints = const <KkToolbarHint>[],
    this.status,
    this.trailing = const <Widget>[],
    this.children,
  });

  /// Controls at the left, usually [KkToolbarGroup]s of small icon buttons.
  final List<Widget> leading;

  /// Keyboard hints after the leading controls.
  final List<KkToolbarHint> hints;

  /// Mono status text pushed to the right: `LINK OK · 14:02:31Z`.
  final String? status;

  /// Widgets after the status text.
  final List<Widget> trailing;

  /// The whole row, instead of the slots.
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final String? statusText = status;
    final List<Widget> row =
        children ??
        <Widget>[
          ...leading,
          if (hints.isNotEmpty) KkRow(shrinkWrap: true, gap: m.space3, children: hints),
          const KkSpacer(),
          if (statusText != null) KkToolbarStatus(statusText),
          ...trailing,
        ];
    return KkBox(
      height: m.toolbarHeight,
      decoration: KkDecoration(
        fill: c.bg100,
        edges: KkEdges(top: KkSide(c.line, width: m.stroke2)),
      ),
      padding: EdgeInsets.symmetric(horizontal: m.space2),
      clip: true,
      child: DefaultTextStyle(
        style: theme.type.mono(11, color: c.inkDim),
        maxLines: 1,
        softWrap: false,
        child: KkRow(gap: m.space4, clip: Clip.hardEdge, children: row),
      ),
    );
  }
}

/// A tight group of small controls in a [KkToolbar], 2px apart.
class KkToolbarGroup extends StatelessWidget {
  const KkToolbarGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => KkRow(shrinkWrap: true, gap: 2, children: children);
}

/// One keyboard hint in a [KkToolbar]: a key cap and what the key does.
class KkToolbarHint extends StatelessWidget {
  const KkToolbarHint({super.key, required this.keys, required this.label});

  /// The key or chord as it should read on the cap: `F5`, `CTRL+K`.
  final String keys;

  /// What it does; upper-cased.
  final String label;

  @override
  Widget build(BuildContext context) {
    final KkColors c = KeikaiTheme.of(context).colors;
    return Semantics(
      container: true,
      label: '$keys: $label',
      child: ExcludeSemantics(
        child: KkRow(
          shrinkWrap: true,
          gap: 6,
          children: <Widget>[
            KkKbd(keys),
            KkText.en(label, size: 11, weight: FontWeight.w600, spacing: 0.12, color: c.inkDim),
          ],
        ),
      ),
    );
  }
}

/// The status line of a [KkToolbar]: one line of 11px mono in dim ink.
class KkToolbarStatus extends StatelessWidget {
  const KkToolbarStatus(this.text, {super.key, this.color});

  final String text;

  /// Defaults to dim ink.
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      KkText.num(text, size: 11, color: color ?? KeikaiTheme.of(context).colors.inkDim);
}
