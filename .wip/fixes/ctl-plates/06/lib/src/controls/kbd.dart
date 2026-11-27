import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../painting/shapes.dart';
import '../widgets/text.dart';
import 'control_style.dart';

/// A key cap: the shortcut hint beside a menu item, a search bar or a toolbar
/// action. 18px high, mono, with a heavier bottom edge.
class KkKbd extends StatelessWidget {
  const KkKbd(this.text, {super.key, this.color, this.edgeColor});

  /// The key, as it should read: `F5`, `ESC`, `CTRL+K`.
  final String text;

  /// Text colour. Defaults to dim ink.
  final Color? color;

  /// Outline colour. Defaults to faint ink.
  final Color? edgeColor;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final Color edge = edgeColor ?? c.inkFaint;
    final KkSide thin = KkSide(edge, width: m.stroke1);
    return KkBox(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      edges: KkEdges(
        top: thin,
        left: thin,
        right: thin,
        bottom: KkSide(edge, width: m.stroke2),
      ),
      child: KkWholeWidth(
        child: KkRow(
          shrinkWrap: true,
          clip: Clip.hardEdge,
          children: <Widget>[
            KkText.num(text, size: 10, weight: FontWeight.w600, spacing: 0.04, color: color ?? c.inkDim),
          ],
        ),
      ),
    );
  }
}
