import 'package:flutter/widgets.dart';

import '../controls/control_style.dart';
import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/conveniences.dart';
import '../layout/flex.dart';
import '../painting/shapes.dart';
import '../widgets/icon.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';
import 'shell_paint.dart';

class _KkListScope extends InheritedWidget {
  const _KkListScope({required this.dense, required super.child});

  final bool dense;

  static bool denseOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_KkListScope>()?.dense ?? false;

  @override
  bool updateShouldNotify(_KkListScope oldWidget) => oldWidget.dense != dense;
}

/// A list of rows on the panel colour, separated by hairlines.
///
/// Give it [KkListRow]s (any widget works). [dense] makes every row 32px and
/// drops the second line. [KkList.builder] builds rows lazily in its own
/// scroll view, for long lists.
class KkList extends StatelessWidget {
  const KkList({
    super.key,
    required List<Widget> this.children,
    this.dense = false,
    this.separated = true,
    this.fill,
    this.semanticLabel,
  }) : itemCount = null,
       itemBuilder = null,
       controller = null,
       padding = EdgeInsets.zero;

  /// A scrolling list that builds only the rows near the visible range.
  const KkList.builder({
    super.key,
    required int this.itemCount,
    required NullableIndexedWidgetBuilder this.itemBuilder,
    this.dense = false,
    this.separated = true,
    this.fill,
    this.controller,
    this.padding = EdgeInsets.zero,
    this.semanticLabel,
  }) : children = null;

  final List<Widget>? children;
  final int? itemCount;
  final NullableIndexedWidgetBuilder? itemBuilder;

  /// 32px rows without the second line.
  final bool dense;

  /// Draw the hairline between rows.
  final bool separated;

  /// Ground colour. Defaults to the panel colour (bg-100).
  final Color? fill;

  /// Scroll controller of the [KkList.builder] form.
  final ScrollController? controller;

  /// Padding inside the scroll view of the [KkList.builder] form.
  final EdgeInsets padding;

  /// Names the list for screen readers.
  final String? semanticLabel;

  Widget _row(BuildContext context, Widget row, bool last) {
    if (!separated || last) return row;
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    return KkBox(
      edges: KkEdges(bottom: KkSide(theme.colors.bg200, width: theme.metrics.stroke1)),
      child: row,
    );
  }

  @override
  Widget build(BuildContext context) {
    final KkColors c = KeikaiTheme.of(context).colors;
    final List<Widget>? rows = children;
    final Widget body;
    if (rows != null) {
      body = KkColumn(
        shrinkWrap: true,
        children: <Widget>[
          for (int i = 0; i < rows.length; i++) _row(context, rows[i], i == rows.length - 1),
        ],
      );
    } else {
      final int count = itemCount!;
      final NullableIndexedWidgetBuilder builder = itemBuilder!;
      body = KkListView(
        itemCount: count,
        controller: controller,
        padding: padding,
        itemBuilder: (BuildContext context, int index) {
          final Widget? row = builder(context, index);
          return row == null ? null : _row(context, row, index == count - 1);
        },
      );
    }
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: _KkListScope(
        dense: dense,
        child: KkBox(fill: fill ?? c.bg100, child: body),
      ),
    );
  }
}

/// One row of a [KkList]: a leading mark, a bilingual title over an optional
/// second line, a mono meta value and a trailing slot.
///
/// With [onPressed] the row is a button: it lights up under the pointer and
/// takes keyboard focus. [current] marks the row that is open elsewhere on
/// screen: lightest ground, signal subtitle and the short signal bar at the
/// left edge.
class KkListRow extends StatelessWidget {
  const KkListRow({
    super.key,
    this.leading,
    this.icon,
    this.level,
    this.cjk,
    this.en,
    this.title,
    this.sub,
    this.meta,
    this.trailing,
    this.onPressed,
    this.onLongPress,
    this.current = false,
    this.enabled = true,
    this.dense,
    this.semanticLabel,
  });

  /// The 16px leading slot. It takes the colour of [level], or dim ink.
  final Widget? leading;

  /// An icon for the leading slot, when [leading] is not given.
  final KkIconData? icon;

  /// Colours the leading slot; alone (no [leading], no [icon]) it shows the
  /// status icon of the level.
  final KkLevel? level;

  /// The title in 漢字 or Hangul.
  final String? cjk;

  /// The title in Latin capitals; it is upper-cased.
  final String? en;

  /// A custom title instead of [cjk] and [en].
  final Widget? title;

  /// The second line: one sentence, cut with an ellipsis. Hidden when dense.
  final String? sub;

  /// Short mono text before the trailing slot: a time, a code, a count.
  final String? meta;

  /// The trailing slot: a tag, a switch, a chevron.
  final Widget? trailing;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool current;

  /// False draws the row in faint ink and ignores presses.
  final bool enabled;

  /// 32px high without the second line. Null follows the enclosing [KkList].
  final bool? dense;

  /// Replaces the visible text for screen readers.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final bool isDense = dense ?? _KkListScope.denseOf(context);
    final bool tappable = enabled && (onPressed != null || onLongPress != null);

    Widget row(KkStates s) {
      final bool live = enabled;
      final Color titleInk = live ? c.ink : c.inkFaint;
      final Color dim = live ? c.inkDim : c.inkFaint;
      final Color enInk = live && current ? c.signal : dim;
      final Color leadInk = !live ? c.inkFaint : (level == null ? c.inkDim : c.level(level));
      final Color? ground = !live ? null : (current ? c.bg300 : (s.hovered ? c.bg200 : null));
      final String? cjkText = cjk;
      final String? enText = en;
      final String? subText = sub;
      final String? metaText = meta;
      final Widget? custom = title;
      final Widget? trail = trailing;
      Widget? lead = leading;
      if (lead == null && icon != null) lead = KkIcon(icon!, color: leadInk);
      if (lead == null && level != null) lead = KkGlyph(level: level, size: 12, color: leadInk);

      final Widget titleRow = custom != null
          ? DefaultTextStyle(
              style: theme.type.bodyMd.copyWith(color: titleInk),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              child: custom,
            )
          : KkRow(
              cross: KkCrossAlign.baseline,
              gap: m.space2,
              clip: Clip.hardEdge,
              children: <Widget>[
                if (cjkText != null) KkText.cjk(cjkText, size: 14, height: 1.55, color: titleInk, squeeze: 0.8),
                if (enText != null)
                  KkFlexible(
                    child: KkText.en(
                      enText,
                      size: 12,
                      weight: FontWeight.w600,
                      height: 1.55,
                      spacing: 0.1,
                      color: enInk,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            );

      return KkFocusRing(
        visible: s.focused,
        offset: -m.stroke2,
        width: m.stroke2,
        child: CustomPaint(
          painter: KkItemGroundPainter(
            fill: ground,
            mark: live && current ? KkItemMark.left : KkItemMark.none,
            markColor: c.signal,
            thickness: m.space1,
            length: m.space4,
          ),
          child: KkBox(
            minHeight: isDense ? m.space8 : m.space12,
            padding: EdgeInsets.symmetric(horizontal: m.space3, vertical: isDense ? m.space1 : m.space2),
            child: KkRow(
              gap: m.space3,
              clip: Clip.hardEdge,
              children: <Widget>[
                if (lead != null)
                  KkBox(
                    width: m.space4,
                    alignment: Alignment.center,
                    child: KkInk(color: leadInk, child: lead),
                  ),
                KkExpanded(
                  child: KkColumn(
                    shrinkWrap: true,
                    gap: 3,
                    children: <Widget>[
                      titleRow,
                      if (subText != null && !isDense)
                        KkText.body(
                          subText,
                          size: 12,
                          height: 1.4,
                          color: dim,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (metaText != null) KkText.num(metaText, size: 11, color: dim),
                ?trail,
              ],
            ),
          ),
        ),
      );
    }

    if (!tappable) {
      return Semantics(
        container: true,
        label: semanticLabel,
        selected: current ? true : null,
        enabled: enabled ? null : false,
        child: ExcludeSemantics(
          excluding: semanticLabel != null,
          child: row(KkStates(enabled: enabled)),
        ),
      );
    }
    return KkPressable(
      onPressed: onPressed,
      onLongPress: onLongPress,
      selected: current ? true : null,
      semanticLabel: semanticLabel,
      excludeSemantics: semanticLabel != null,
      builder: (BuildContext context, KkStates raw) => row(KkStateOverride.resolve(context, raw)),
    );
  }
}
