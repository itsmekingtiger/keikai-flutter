import 'package:keikai/keikai.dart';

import '../shell/destinations.dart';

/// The top of every screen: where this is (a trail back to the board), what
/// it is called in two languages, one line on what it is for, and the
/// screen's own actions at the right.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.destination,
    this.trail = const <KkCrumb>[],
    this.note,
    this.actions = const <Widget>[],
  });

  /// The title grows with the window: 24px on a phone, 32px from 840px, 36px
  /// on a wide monitor.
  static const KkResponsive<double> _titleSize = KkResponsive<double>(compact: 24, expanded: 32, xlarge: 36);
  static const KkResponsive<double> _subtitleSize = KkResponsive<double>(compact: 13, expanded: 15);

  final Destination destination;

  /// Steps below the destination, such as the sheet shown in the catalogue.
  final List<KkCrumb> trail;

  /// One sentence under the title.
  final String? note;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final KkColors c = context.kk.colors;
    final bool compact = KkWindowScope.of(context) == KkWindowClass.compact;
    final bool home = destination == Destination.situation;
    final String? line = note;
    final Widget crumbs = KkBreadcrumbs(
      items: <KkCrumb>[
        KkCrumb(code: 'HQ-03', en: 'board', onPressed: home ? null : () => goTo(context, Destination.situation)),
        if (!home)
          KkCrumb(
            cjk: destination.cjk,
            en: destination.en,
            onPressed: trail.isEmpty ? null : () => goTo(context, destination),
          ),
        ...trail,
      ],
    );
    final Widget title = KkColumn(
      gap: 6,
      shrinkWrap: true,
      cross: KkCrossAlign.start,
      children: <Widget>[
        crumbs,
        Semantics(
          header: true,
          child: KkLabel(
            cjk: destination.cjk,
            en: destination.en,
            cjkSize: _titleSize.of(context),
            enSize: _subtitleSize.of(context),
          ),
        ),
        if (line != null) KkText.body(line, size: 12, height: 1.5, color: c.inkDim),
      ],
    );
    final Widget buttons = KkWrap(gap: 8, runGap: 8, children: actions);
    if (actions.isEmpty) return title;
    if (compact) {
      return KkColumn(gap: 12, shrinkWrap: true, cross: KkCrossAlign.start, children: <Widget>[title, buttons]);
    }
    return KkRow(
      gap: 16,
      cross: KkCrossAlign.end,
      children: <Widget>[
        KkExpanded(child: title),
        buttons,
      ],
    );
  }
}
