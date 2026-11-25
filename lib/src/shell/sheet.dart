import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../app/routes.dart';
import '../controls/icon_button.dart';
import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../layout/scroll.dart';
import '../layout/wrap.dart';
import '../painting/decoration.dart';
import '../painting/patterns.dart';
import '../painting/shapes.dart';
import '../widgets/text.dart';

/// The edge a [KkSheet] is attached to.
enum KkSheetSide { right, left, bottom }

class _KkSheetScope extends InheritedWidget {
  const _KkSheetScope({required this.side, required super.child});

  final KkSheetSide side;

  static KkSheetSide? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_KkSheetScope>()?.side;

  @override
  bool updateShouldNotify(_KkSheetScope oldWidget) => oldWidget.side != side;
}

/// A sheet: a surface attached to an edge of the screen that holds detail or
/// a short task without leaving the page.
///
/// A side sheet is 400px wide (the full width when there is less) with a 2px
/// signal line on its inner edge; a bottom sheet spans the width with the
/// line on top and a grip of dashes. The 44px head carries a code, the
/// bilingual title and a close button; the body scrolls; [actions] sit
/// right-aligned in a foot row.
///
/// Show it with [showKkSheet], or place it directly in a layout (beside the
/// body of a `KkScreen`, for example).
class KkSheet extends StatelessWidget {
  const KkSheet({
    super.key,
    this.side,
    this.code,
    this.cjk,
    this.en,
    this.actions = const <Widget>[],
    this.onClose,
    this.showClose = true,
    this.closeLabel = 'Close',
    this.grip,
    this.width,
    this.padding,
    this.scrollable = true,
    this.semanticLabel,
    required this.child,
  });

  /// The edge the sheet belongs to. Inside [showKkSheet] it defaults to the
  /// side the sheet was shown from; elsewhere to the right.
  final KkSheetSide? side;

  /// A short code before the title, in signal: `SEC-04`.
  final String? code;

  /// The title in 漢字 or Hangul.
  final String? cjk;

  /// The title in Latin capitals; it is upper-cased.
  final String? en;

  /// Buttons for the foot row; the main action goes last.
  final List<Widget> actions;

  /// Called by the close button. Defaults to popping the enclosing route.
  final VoidCallback? onClose;
  final bool showClose;

  /// What screen readers call the close button.
  final String closeLabel;

  /// Show the grip of dashes on top. Defaults to true for a bottom sheet.
  final bool? grip;

  /// Width of a side sheet. Defaults to the theme's sheet width (400).
  final double? width;

  /// Padding of the body. Defaults to 16.
  final EdgeInsets? padding;

  /// Let the body scroll.
  final bool scrollable;

  /// The name screen readers announce. Defaults to the title.
  final String? semanticLabel;

  /// The body. It inherits 14px body type in ink.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final KkSheetSide edge = side ?? _KkSheetScope.maybeOf(context) ?? KkSheetSide.right;
    final bool showGrip = grip ?? edge == KkSheetSide.bottom;
    final String? codeText = code;
    final String? cjkText = cjk;
    final String? enText = en;
    final KkSide line = KkSide(c.signal, width: m.stroke2);

    final Widget head = KkBox(
      height: 44,
      padding: EdgeInsets.only(left: m.space4, right: m.space2),
      edges: KkEdges(bottom: KkSide(c.line, width: m.stroke1)),
      child: KkRow(
        gap: m.space3,
        clip: Clip.hardEdge,
        children: <Widget>[
          if (codeText != null) KkText.num(codeText, size: 11, weight: FontWeight.w600, color: c.signal),
          KkExpanded(
            child: KkRow(
              cross: KkCrossAlign.baseline,
              gap: m.space2,
              clip: Clip.hardEdge,
              children: <Widget>[
                if (cjkText != null) KkText.cjk(cjkText, size: 18, color: c.ink, squeeze: 0.8),
                if (enText != null)
                  KkFlexible(
                    child: KkText.en(
                      enText,
                      size: 11,
                      weight: FontWeight.w600,
                      spacing: 0.14,
                      color: c.inkDim,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          if (showClose)
            KkIconButton(
              icon: KkIcons.close,
              semanticLabel: closeLabel,
              onPressed: onClose ?? () => Navigator.maybePop(context),
            ),
        ],
      ),
    );

    Widget body = KkBox(
      padding: padding ?? EdgeInsets.all(m.space4),
      child: DefaultTextStyle(style: theme.type.bodyMd.copyWith(color: c.ink), child: child),
    );
    if (scrollable) body = KkScroll(child: body);

    final String label =
        semanticLabel ??
        <String>[?cjkText, ?enText?.toUpperCase()].join(' ');

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: label.isEmpty ? null : label,
      child: KkBox(
        width: edge == KkSheetSide.bottom ? null : (width ?? m.sheetWidth),
        decoration: KkDecoration(
          fill: c.bg100,
          edges: switch (edge) {
            KkSheetSide.right => KkEdges(left: line),
            KkSheetSide.left => KkEdges(right: line),
            KkSheetSide.bottom => KkEdges(top: line),
          },
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // A sheet pinned to the full height keeps its foot on the bottom
            // edge; a free-standing one is as tall as its content.
            final bool pinned = constraints.hasTightHeight;
            return KkColumn(
              shrinkWrap: !pinned,
              children: <Widget>[
                if (showGrip)
                  KkAlignSelf(
                    align: KkCrossAlign.center,
                    child: KkBox(
                      padding: EdgeInsets.only(top: m.space2),
                      child: KkBox(
                        width: m.space8,
                        height: m.space1,
                        decoration: KkDecoration(pattern: KkPattern.segments(color: c.inkFaint, pitch: 9, gap: 3)),
                      ),
                    ),
                  ),
                head,
                if (pinned) KkExpanded(child: body) else KkFlexible(child: body),
                if (actions.isNotEmpty)
                  KkBox(
                    padding: EdgeInsets.symmetric(horizontal: m.space4, vertical: m.space3),
                    edges: KkEdges(top: KkSide(c.line, width: m.stroke1)),
                    child: KkWrap(gap: m.space2, runGap: m.space2, main: KkMainAlign.end, children: actions),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Slides a sheet in from [side] over the current screen and returns what it
/// was popped with.
///
/// [builder] usually returns a [KkSheet]; it takes its side from here. The
/// screen behind is dimmed with the 70% scrim unless [scrim] is false. The
/// sheet steps in from its edge (0.42s in 7 steps) and steps out when it
/// closes. Escape and a tap outside close it unless [dismissible] is false;
/// keyboard focus stays inside while it is open.
Future<T?> showKkSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  KkSheetSide side = KkSheetSide.right,
  bool dismissible = true,
  bool scrim = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  String barrierLabel = 'Dismiss',
}) {
  final Color veil = KeikaiTheme.of(context).colors.scrimSheet;
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    KkPopupRoute<T>(
      scrim: scrim ? veil : null,
      dismissible: dismissible,
      label: barrierLabel,
      settings: routeSettings,
      builder: (BuildContext context, Animation<double> animation) =>
          _KkSheetPage(animation: animation, side: side, child: Builder(builder: builder)),
    ),
  );
}

class _KkSheetPage extends StatelessWidget {
  const _KkSheetPage({required this.animation, required this.side, required this.child});

  final Animation<double> animation;
  final KkSheetSide side;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final Offset from = switch (side) {
      KkSheetSide.right => const Offset(1, 0),
      KkSheetSide.left => const Offset(-1, 0),
      KkSheetSide.bottom => const Offset(0, 1),
    };
    final Animation<Offset> slide = animation.drive(
      Tween<Offset>(
        begin: from,
        end: Offset.zero,
      ).chain(CurveTween(curve: const KkSteps(KkMotion.bootSteps))),
    );
    // A scope of its own closes the Tab loop inside the sheet.
    final Widget sheet = FocusScope(
      autofocus: true,
      child: _KkSheetScope(
        side: side,
        child: SlideTransition(position: slide, child: child),
      ),
    );
    final Widget placed = switch (side) {
      KkSheetSide.right || KkSheetSide.left => KkRow(
        main: side == KkSheetSide.right ? KkMainAlign.end : KkMainAlign.start,
        cross: KkCrossAlign.stretch,
        children: <Widget>[KkFlexible(child: sheet)],
      ),
      KkSheetSide.bottom => KkColumn(
        main: KkMainAlign.end,
        children: <Widget>[
          KkFlexible(
            child: KkBox(maxHeight: mq.size.height * 0.6, child: sheet),
          ),
        ],
      ),
    };
    final double keyboard = mq.viewInsets.bottom;
    if (keyboard <= 0) return placed;
    return KkBox(
      padding: EdgeInsets.only(bottom: math.min(keyboard, mq.size.height)),
      child: placed,
    );
  }
}
