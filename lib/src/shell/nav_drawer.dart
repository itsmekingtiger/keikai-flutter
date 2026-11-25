import 'package:flutter/widgets.dart';

import '../controls/control_style.dart';
import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../layout/scroll.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/icon.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';
import 'shell_paint.dart';

/// One destination of a [KkNavDrawer].
@immutable
class KkNavDrawerItem<T> {
  const KkNavDrawerItem({
    required this.value,
    this.icon,
    this.cjk,
    this.en,
    this.meta,
    this.level,
    this.enabled = true,
    this.semanticLabel,
  }) : assert(cjk != null || en != null, 'A drawer item needs a title.');

  /// What [KkNavDrawer.onChanged] reports when this destination is chosen.
  final T value;
  final KkIconData? icon;

  /// The title in 漢字 or Hangul.
  final String? cjk;

  /// The title in Latin capitals; it is upper-cased.
  final String? en;

  /// Short mono text at the right: a count, a code, a reading.
  final String? meta;

  /// Shows the status icon of this level before [meta].
  final KkLevel? level;
  final bool enabled;

  /// Replaces the visible text for screen readers.
  final String? semanticLabel;
}

/// A titled group of destinations in a [KkNavDrawer].
@immutable
class KkNavSection<T> {
  const KkNavSection({this.cjk, this.en, this.code, required this.items});

  final String? cjk;

  /// Upper-cased.
  final String? en;

  /// A short mono code after the title: `NAV-02`.
  final String? code;
  final List<KkNavDrawerItem<T>> items;
}

/// The wide navigation column: sections of destinations with full titles and
/// a reading or status at the right of each.
///
/// 256px wide on the panel colour. The current destination has the lightest
/// ground, a lit icon and a short signal bar at its left edge. The [foot]
/// stays on the bottom edge; the drawer scrolls when it is taller than the
/// space it is given. With [onChanged] null every destination is disabled.
class KkNavDrawer<T> extends StatelessWidget {
  const KkNavDrawer({
    super.key,
    required this.sections,
    this.value,
    this.onChanged,
    this.head,
    this.foot,
    this.width,
    this.semanticLabel = 'Navigation',
  });

  final List<KkNavSection<T>> sections;

  /// The [KkNavDrawerItem.value] of the current destination.
  final T? value;
  final ValueChanged<T>? onChanged;

  /// A slot above the sections (a heading, a search field).
  final Widget? head;

  /// A slot pinned to the bottom, under a line. It inherits 11px mono in dim
  /// ink: build info, operator, uptime.
  final Widget? foot;

  /// Defaults to the theme's drawer width (256).
  final double? width;

  /// Names the drawer for screen readers.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final Widget? top = head;
    final Widget? bottom = foot;

    final Widget content = KkBox(
      padding: EdgeInsets.symmetric(horizontal: m.space2, vertical: m.space3),
      // `between` keeps the foot on the bottom edge whenever there is room.
      child: KkColumn(
        main: KkMainAlign.between,
        gap: m.space4,
        children: <Widget>[
          KkColumn(
            shrinkWrap: true,
            gap: m.space4,
            children: <Widget>[
              if (top != null)
                KkBox(
                  padding: EdgeInsets.symmetric(horizontal: m.space2),
                  child: top,
                ),
              for (final KkNavSection<T> section in sections) _section(context, section),
            ],
          ),
          if (bottom != null)
            KkBox(
              padding: EdgeInsets.fromLTRB(m.space2, m.space2, m.space2, 0),
              edges: KkEdges(top: KkSide(c.line, width: m.stroke1)),
              child: DefaultTextStyle(
                style: theme.type.mono(11, height: 1.5, color: c.inkDim),
                child: bottom,
              ),
            ),
        ],
      ),
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: KkBox(
        width: width ?? m.drawerWidth,
        decoration: KkDecoration(
          fill: c.bg100,
          edges: KkEdges(right: KkSide(c.line, width: m.stroke1)),
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            if (!constraints.hasBoundedHeight) return content;
            return KkScroll(
              child: KkBox(minHeight: constraints.maxHeight, child: content),
            );
          },
        ),
      ),
    );
  }

  Widget _section(BuildContext context, KkNavSection<T> section) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final String? cjk = section.cjk;
    final String? en = section.en;
    final String? code = section.code;
    final bool titled = cjk != null || en != null || code != null;
    return KkColumn(
      shrinkWrap: true,
      gap: 2,
      children: <Widget>[
        if (titled)
          KkBox(
            padding: EdgeInsets.fromLTRB(m.space2, 0, m.space2, m.space1),
            child: KkRow(
              cross: KkCrossAlign.baseline,
              gap: m.space2,
              clip: Clip.hardEdge,
              children: <Widget>[
                if (cjk != null) KkText.cjk(cjk, size: 12, height: 1.55, color: c.inkDim, squeeze: 0.8),
                if (en != null)
                  KkText.en(en, size: 10, weight: FontWeight.w600, height: 1.55, spacing: 0.16, color: c.inkFaint),
                if (code != null) KkText.num(code, size: 10, weight: FontWeight.w500, color: c.inkFaint),
              ],
            ),
          ),
        for (final KkNavDrawerItem<T> item in section.items)
          _KkNavDrawerRow<T>(
            item: item,
            current: value != null && item.value == value,
            onPressed: onChanged != null && item.enabled ? () => onChanged!(item.value) : null,
          ),
      ],
    );
  }
}

class _KkNavDrawerRow<T> extends StatelessWidget {
  const _KkNavDrawerRow({required this.item, required this.current, required this.onPressed});

  final KkNavDrawerItem<T> item;
  final bool current;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final KkIconData? icon = item.icon;
    final String? cjk = item.cjk;
    final String? en = item.en;
    final String? meta = item.meta;
    final KkLevel? level = item.level;
    return KkPressable(
      onPressed: onPressed,
      selected: current,
      semanticLabel: item.semanticLabel,
      excludeSemantics: item.semanticLabel != null,
      builder: (BuildContext context, KkStates raw) {
        final KkStates s = KkStateOverride.resolve(context, raw);
        final bool lit = s.enabled && (current || s.hovered);
        final Color ink = !s.enabled ? c.inkFaint : (lit ? c.ink : c.inkDim);
        final Color titleInk = s.enabled ? c.ink : c.inkFaint;
        final Color? ground = !s.enabled ? null : (current ? c.bg300 : (s.hovered ? c.bg200 : null));
        return KkFocusRing(
          visible: s.focused,
          offset: -m.stroke2,
          width: m.stroke2,
          child: CustomPaint(
            painter: KkItemGroundPainter(
              fill: ground,
              mark: s.enabled && current ? KkItemMark.left : KkItemMark.none,
              markColor: c.signal,
              thickness: m.space1,
              length: m.space4,
            ),
            child: KkBox(
              height: 36,
              padding: EdgeInsets.symmetric(horizontal: m.space3),
              child: KkRow(
                gap: 10,
                clip: Clip.hardEdge,
                children: <Widget>[
                  if (icon != null) KkIcon(icon, color: s.enabled && current ? c.signal : ink),
                  KkExpanded(
                    child: KkRow(
                      cross: KkCrossAlign.baseline,
                      gap: m.space2,
                      clip: Clip.hardEdge,
                      children: <Widget>[
                        if (cjk != null) KkText.cjk(cjk, size: 14, color: titleInk, squeeze: 0.8),
                        if (en != null)
                          KkFlexible(
                            child: KkText.en(
                              en,
                              size: 11,
                              weight: FontWeight.w600,
                              spacing: 0.12,
                              color: ink,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (meta != null || level != null)
                    KkRow(
                      shrinkWrap: true,
                      gap: 5,
                      children: <Widget>[
                        if (level != null) KkGlyph(level: level, size: 10),
                        if (meta != null)
                          KkText.num(meta, size: 11, weight: FontWeight.w500, color: s.enabled ? c.inkDim : c.inkFaint),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
