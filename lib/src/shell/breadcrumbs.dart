import 'package:flutter/widgets.dart';

import '../controls/control_style.dart';
import '../foundation/colors.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../layout/wrap.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';

/// One step of a [KkBreadcrumbs] trail.
@immutable
class KkCrumb {
  const KkCrumb({this.cjk, this.en, this.code, this.onPressed, this.semanticLabel})
    : assert(cjk != null || en != null || code != null, 'A crumb needs something to show.');

  /// The name in 漢字 or Hangul.
  final String? cjk;

  /// The name in Latin capitals; it is upper-cased.
  final String? en;

  /// A short mono code before the name: `SEC-04`.
  final String? code;

  /// Goes to this step. A crumb without one (and the last crumb) is plain text.
  final VoidCallback? onPressed;

  /// Replaces the visible text for screen readers.
  final String? semanticLabel;
}

/// The trail from the top of the app to the current page.
///
/// Every crumb but the last is a link in signal that underlines under the
/// pointer; the last is the current page, in ink. The trail wraps when it
/// does not fit on one line.
class KkBreadcrumbs extends StatelessWidget {
  const KkBreadcrumbs({super.key, required this.items, this.separator, this.semanticLabel = 'Breadcrumb'});

  final List<KkCrumb> items;

  /// Drawn between crumbs in faint ink. Defaults to a slash.
  final Widget? separator;

  /// Names the trail for screen readers.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: KkWrap(
        gap: 6,
        runGap: 6,
        children: <Widget>[
          for (int i = 0; i < items.length; i++)
            KkRow(
              shrinkWrap: true,
              gap: 6,
              children: <Widget>[
                _KkCrumbLink(crumb: items[i], current: i == items.length - 1),
                if (i < items.length - 1)
                  ExcludeSemantics(
                    child: KkInk(
                      color: c.inkFaint,
                      child:
                          separator ??
                          KkText.en('/', size: 12, weight: FontWeight.w600, spacing: 0, color: c.inkFaint),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _KkCrumbLink extends StatelessWidget {
  const _KkCrumbLink({required this.crumb, required this.current});

  final KkCrumb crumb;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final String? code = crumb.code;
    final String? cjk = crumb.cjk;
    final String? en = crumb.en;
    final bool link = !current && crumb.onPressed != null;

    Widget content(Color ink) => KkRow(
      shrinkWrap: true,
      cross: KkCrossAlign.baseline,
      gap: 0,
      children: <Widget>[
        if (code != null && code.isNotEmpty)
          KkBox(
            padding: const EdgeInsets.only(right: 4),
            child: KkText.num(code, size: 10, weight: FontWeight.w500, color: c.inkFaint),
          ),
        if (cjk != null && cjk.isNotEmpty)
          KkBox(
            padding: EdgeInsets.only(right: en != null && en.isNotEmpty ? 6 : 0),
            child: KkText.cjk(cjk, size: 13, color: ink, squeeze: 0.8),
          ),
        if (en != null && en.isNotEmpty) KkText.en(en, size: 12, weight: FontWeight.w600, spacing: 0.1, color: ink),
      ],
    );

    if (!link) {
      // The current page, or a step that leads nowhere.
      return Semantics(
        container: true,
        label: crumb.semanticLabel,
        selected: current ? true : null,
        child: ExcludeSemantics(
          excluding: crumb.semanticLabel != null,
          child: KkBox(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: content(current ? c.ink : c.inkFaint),
          ),
        ),
      );
    }
    return KkPressable(
      onPressed: crumb.onPressed,
      button: false,
      semanticLabel: crumb.semanticLabel,
      excludeSemantics: crumb.semanticLabel != null,
      builder: (BuildContext context, KkStates raw) {
        final KkStates s = KkStateOverride.resolve(context, raw);
        return Semantics(
          link: true,
          child: KkFocusRing(
            visible: s.focused,
            offset: 2,
            width: m.stroke2,
            child: CustomPaint(
              foregroundPainter: _UnderlinePainter(color: s.hovered ? c.signal : null),
              child: KkBox(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: content(c.signal),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The hover underline of a link, 3px under the baseline of 12px label type.
class _UnderlinePainter extends CustomPainter {
  const _UnderlinePainter({required this.color});

  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    final Color? ink = color;
    if (ink == null) return;
    canvas.drawRect(Rect.fromLTWH(0, size.height - 3, size.width, 1), Paint()..color = ink);
  }

  @override
  bool shouldRepaint(_UnderlinePainter oldDelegate) => oldDelegate.color != color;
}
