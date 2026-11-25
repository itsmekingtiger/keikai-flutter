import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/widgets.dart';

import '../app/routes.dart';
import '../controls/button.dart';
import '../controls/control_style.dart';
import '../controls/icon_button.dart';
import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/level.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../layout/scroll.dart';
import '../layout/wrap.dart';
import '../motion/effects.dart';
import '../motion/entrances.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/text.dart';

/// A dialog: a framed panel that floats over the screen and waits for a
/// decision.
///
/// 520px wide (never wider than the space it is given), on the panel colour
/// with a 1px signal border, the signal glow and four corner brackets sitting
/// 6px outside. The 40px head carries a code block, the bilingual title and a
/// close button; the body scrolls when it is too tall; the [actions] sit
/// right-aligned in a foot row.
///
/// With [level] critical the frame, glow and code block turn to the alert
/// colour and the head to the deep alert fill.
///
/// Show it with [showKkDialog], or place it directly in a layout.
class KkDialog extends StatelessWidget {
  const KkDialog({
    super.key,
    this.code,
    this.cjk,
    this.en,
    this.level,
    this.hazard = false,
    this.width,
    this.actions = const <Widget>[],
    this.onClose,
    this.showClose = true,
    this.closeLabel = 'Close',
    this.padding,
    this.scrollable = true,
    this.semanticLabel,
    required this.child,
  });

  /// The code on the head's plate: `DLG-07`, `E-4127`.
  final String? code;

  /// The title in 漢字 or Hangul.
  final String? cjk;

  /// The title in Latin capitals; it is upper-cased.
  final String? en;

  /// Critical makes this an alarm dialog.
  final KkLevel? level;

  /// An 8px hazard strip across the top. It runs while [level] is critical.
  final bool hazard;

  /// Defaults to the theme's dialog width (520). The design allows up to 720.
  final double? width;

  /// Buttons for the foot row, in reading order; the main action goes last.
  final List<Widget> actions;

  /// Called by the close button. Defaults to popping the enclosing route.
  final VoidCallback? onClose;

  /// Show the close button in the head.
  final bool showClose;

  /// What screen readers call the close button.
  final String closeLabel;

  /// Padding of the body. Defaults to 16.
  final EdgeInsets? padding;

  /// Let the body scroll when the dialog would be taller than its space.
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
    final bool critical = level == KkLevel.critical;
    final Color frame = critical ? c.alert : c.signal;
    final String? codeText = code;
    final String? cjkText = cjk;
    final String? enText = en;

    final Widget head = KkBox(
      height: 40,
      decoration: KkDecoration(
        fill: critical ? c.alertDeep : c.bg200,
        edges: KkEdges(bottom: KkSide(critical ? c.alert : c.line, width: m.stroke1)),
      ),
      padding: EdgeInsets.only(left: codeText == null ? m.space4 : 0, right: m.space2),
      child: KkRow(
        gap: m.space3,
        clip: Clip.hardEdge,
        children: <Widget>[
          if (codeText != null)
            KkAlignSelf(
              align: KkCrossAlign.stretch,
              child: KkSurface(
                shape: KkShape.slant(m.chamferLg),
                fill: frame,
                edgeWidth: 0,
                child: KkBox(
                  padding: EdgeInsets.only(left: m.space3, right: m.space2 + m.chamferLg),
                  alignment: Alignment.center,
                  child: KkText.num(codeText, size: 11, weight: FontWeight.w600, spacing: 0.06, color: c.onFill),
                ),
              ),
            ),
          KkExpanded(
            child: KkRow(
              cross: KkCrossAlign.baseline,
              gap: m.space2,
              clip: Clip.hardEdge,
              children: <Widget>[
                if (cjkText != null) KkText.cjk(cjkText, size: 19, color: c.ink, squeeze: 0.8),
                if (enText != null)
                  KkFlexible(
                    child: KkText.en(
                      enText,
                      size: 12,
                      weight: FontWeight.w600,
                      spacing: 0.14,
                      color: critical ? c.ink : c.inkDim,
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
              style: critical ? KkPlateStyle(ink: c.ink) : null,
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

    final Widget panel = KkBox(
      width: width ?? m.dialogWidth,
      decoration: KkDecoration(
        fill: c.bg100,
        edges: KkEdges.line(frame, width: m.stroke1),
        glow: critical ? c.glowAlert : c.glowSignal,
        brackets: KkBracketSpec(color: frame, length: m.space3, width: m.stroke2, outset: 6),
      ),
      child: KkColumn(
        shrinkWrap: true,
        children: <Widget>[
          if (hazard) KkHazard(level: level, height: m.space2, running: critical),
          head,
          KkFlexible(
            child: KkFlicker(delay: const Duration(milliseconds: 300), stagger: false, child: body),
          ),
          if (actions.isNotEmpty)
            KkBox(
              padding: EdgeInsets.symmetric(horizontal: m.space4, vertical: m.space3),
              edges: KkEdges(top: KkSide(c.line, width: m.stroke1)),
              child: KkWrap(gap: m.space2, runGap: m.space2, main: KkMainAlign.end, children: actions),
            ),
        ],
      ),
    );

    final String label =
        semanticLabel ??
        <String>[?cjkText, ?enText?.toUpperCase()].join(' ');
    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: critical ? SemanticsRole.alertDialog : SemanticsRole.dialog,
      label: label.isEmpty ? null : label,
      child: panel,
    );
  }
}

/// Shows a dialog over the current screen and returns what it was popped
/// with.
///
/// [builder] usually returns a [KkDialog]. The screen behind is dimmed with
/// the 78% scrim, which snaps in. The dialog wipes in from the left (0.42s in
/// 7 steps) and wipes out again when it closes.
///
/// Escape and a tap on the scrim close it unless [dismissible] is false.
/// Keyboard focus stays inside the dialog while it is open and goes back to
/// where it was afterwards.
Future<T?> showKkDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dismissible = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  String barrierLabel = 'Dismiss',
}) {
  final Color scrim = KeikaiTheme.of(context).colors.scrim;
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    KkPopupRoute<T>(
      scrim: scrim,
      dismissible: dismissible,
      label: barrierLabel,
      settings: routeSettings,
      builder: (BuildContext context, Animation<double> animation) =>
          _KkDialogPage(animation: animation, child: Builder(builder: builder)),
    ),
  );
}

/// Asks a yes / no question in a dialog. Completes with true when the
/// operator confirms and false otherwise (cancel, close, Escape, scrim).
///
/// With [danger] the dialog is an alarm dialog with a hazard strip, the
/// confirm button is the danger button, and the keyboard starts on cancel.
Future<bool> showKkConfirm({
  required BuildContext context,
  String? code,
  String? cjk,
  String? en,
  required String message,
  String confirmLabel = 'confirm',
  String? confirmCjk,
  String cancelLabel = 'cancel',
  String? cancelCjk,
  bool danger = false,
  bool dismissible = true,
  bool useRootNavigator = true,
}) async {
  final bool? result = await showKkDialog<bool>(
    context: context,
    dismissible: dismissible,
    useRootNavigator: useRootNavigator,
    builder: (BuildContext context) => KkDialog(
      code: code,
      cjk: cjk,
      en: en,
      level: danger ? KkLevel.critical : null,
      hazard: danger,
      showClose: dismissible,
      onClose: () => Navigator.of(context).pop(false),
      actions: <Widget>[
        KkButton(
          label: cancelLabel,
          cjk: cancelCjk,
          variant: KkButtonVariant.ghost,
          autofocus: danger,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        KkButton(
          label: confirmLabel,
          cjk: confirmCjk,
          variant: danger ? KkButtonVariant.danger : KkButtonVariant.primary,
          autofocus: !danger,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
      child: KkText.body(message),
    ),
  );
  return result ?? false;
}

class _KkDialogPage extends StatelessWidget {
  const _KkDialogPage({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final KkMetrics m = KeikaiTheme.of(context).metrics;
    final MediaQueryData mq = MediaQuery.of(context);
    final EdgeInsets inset = mq.padding.copyWith(bottom: math.max(mq.padding.bottom, mq.viewInsets.bottom));
    return KkBox(
      padding: EdgeInsets.all(m.space4) + inset,
      alignment: Alignment.center,
      child: KkBox(
        maxHeight: math.max(0, mq.size.height - m.space12 - inset.vertical),
        // A scope of its own closes the Tab loop inside the dialog.
        child: FocusScope(
          autofocus: true,
          child: KkRouteWipe(animation: animation, child: child),
        ),
      ),
    );
  }
}

/// Wipes its child in from the left as a route [animation] runs forward and
/// out again as it reverses, in [steps] jumps. Once the route is fully open
/// the clip is lifted, so glows and brackets outside the child's box show.
class KkRouteWipe extends StatefulWidget {
  const KkRouteWipe({super.key, required this.animation, this.steps = KkMotion.bootSteps, required this.child});

  final Animation<double> animation;
  final int steps;
  final Widget child;

  @override
  State<KkRouteWipe> createState() => _KkRouteWipeState();
}

class _KkRouteWipeState extends State<KkRouteWipe> {
  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(KkRouteWipe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeStatusListener(_onStatus);
      widget.animation.addStatusListener(_onStatus);
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatus);
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool open = widget.animation.isCompleted;
    return ClipRect(
      clipBehavior: open ? Clip.none : Clip.hardEdge,
      clipper: KkWipeClipper(widget.animation, widget.steps),
      child: widget.child,
    );
  }
}
