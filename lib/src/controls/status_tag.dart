import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/icon.dart';
import '../widgets/text.dart';

/// How a [KkStatusTag] is filled.
enum KkStatusTagVariant {
  /// A 1px outline in the level colour.
  outline,

  /// Filled with the level colour, dark ink on it.
  solid,
}

/// The height of a [KkStatusTag].
enum KkStatusTagSize {
  /// 22px high, 12px type.
  md,

  /// 28px high, 15px type.
  lg,
}

/// A status tag: the smallest statement of a state.
///
/// A state is always said three ways at once: colour, word and status icon.
/// [KkStatusTag.status] builds that tag for a level (`NOMINAL 正常` with the
/// tick plate). The plain constructor makes a tag with any text; without a
/// level it is drawn in signal and carries no status icon.
class KkStatusTag extends StatelessWidget {
  /// A tag with [text] (upper-cased) and an optional [cjk] word after it.
  const KkStatusTag(
    String this.text, {
    super.key,
    this.cjk,
    this.level,
    this.variant = KkStatusTagVariant.outline,
    this.size = KkStatusTagSize.md,
    this.glyph,
    this.icon,
    this.color,
    this.onColor,
  }) : _status = false,
       showCjk = true;

  /// The tag of a level: status icon, the level's word and its 漢字.
  /// A null [level] gives the `INFO` tag.
  const KkStatusTag.status(
    this.level, {
    super.key,
    this.variant = KkStatusTagVariant.outline,
    this.size = KkStatusTagSize.md,
    this.glyph,
    this.showCjk = true,
    this.color,
    this.onColor,
  }) : _status = true,
       text = null,
       cjk = null,
       icon = null;

  /// The Latin word. Null only for [KkStatusTag.status].
  final String? text;

  /// A CJK word shown after [text].
  final String? cjk;

  /// Colours the tag and picks the status icon.
  final KkLevel? level;
  final KkStatusTagVariant variant;
  final KkStatusTagSize size;

  /// Show the status icon. Defaults to true when the tag has a level (or was
  /// built with [KkStatusTag.status]).
  final bool? glyph;

  /// A general icon in front of the text instead of the status icon. Never
  /// use one to say a level.
  final KkIconData? icon;

  /// Show the level's 漢字 after its word ([KkStatusTag.status] only).
  final bool showCjk;

  /// Overrides the level colour (or signal).
  final Color? color;

  /// Text colour on a solid tag. Defaults to the on-fill ink.
  final Color? onColor;

  final bool _status;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final bool lg = size == KkStatusTagSize.lg;
    final bool solid = variant == KkStatusTagVariant.solid;
    final Color lv = color ?? c.level(level);
    final Color ink = solid ? (onColor ?? c.onFill) : lv;
    final double type = lg ? 15 : 12;
    final String word = text ?? level?.word ?? 'INFO';
    final String? cjkWord = _status ? (showCjk ? level?.cjk : null) : cjk;
    final bool showGlyph = glyph ?? (_status || level != null);
    final KkIconData? custom = icon;
    return KkBox(
      height: lg ? 28 : 22,
      padding: EdgeInsets.symmetric(horizontal: lg ? m.space3 : m.space2),
      decoration: KkDecoration(
        fill: solid ? lv : null,
        edges: KkEdges.line(lv, width: m.stroke1),
      ),
      child: KkRow(
        shrinkWrap: true,
        gap: lg ? m.space2 : 6,
        children: <Widget>[
          if (custom != null)
            KkIcon(custom, size: lg ? 14 : 12, color: ink)
          else if (showGlyph)
            KkGlyph(level: level, size: lg ? 14 : 12, color: ink),
          if (word.isNotEmpty) KkText.en(word, size: type, spacing: 0.12, color: ink),
          if (cjkWord != null && cjkWord.isNotEmpty) KkText.cjk(cjkWord, size: type, color: ink, squeeze: 0.8),
        ],
      ),
    );
  }
}
