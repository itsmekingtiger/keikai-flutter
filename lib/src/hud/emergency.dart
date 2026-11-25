import 'package:flutter/widgets.dart';

import '../app/routes.dart';
import '../foundation/colors.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../layout/layers.dart';
import '../motion/effects.dart';
import '../widgets/frame.dart';
import '../widgets/text.dart';
import 'fill_column.dart';

/// The full-screen alarm.
///
/// A deep red veil, running hazard bands and marquees at the top and bottom,
/// and in the middle a plate that strobes between the alert fill and its dark
/// phase once a second. Use it once per screen and only for a real alarm.
///
/// [inline] places it in the layout (at least 420px tall) instead of over the
/// whole screen; [showKkEmergency] pushes it on top of everything.
class KkEmergency extends StatelessWidget {
  const KkEmergency({
    super.key,
    this.code,
    required this.cjk,
    this.en,
    this.sub,
    this.marquee,
    this.actions = const <Widget>[],
    this.inline = false,
    this.minHeight,
    this.squeeze = 0.8,
  });

  /// The mono line at the top of the plate, such as `E-4127 · SEC-04`.
  final String? code;

  /// The alarm in a few CJK characters, such as `緊急停止`.
  final String cjk;

  /// The alarm in Latin capitals.
  final String? en;

  /// One mono line of detail under the titles.
  final String? sub;

  /// The text of the two marquees. Defaults to the code, Latin line and sub
  /// line joined; an empty string hides them.
  final String? marquee;

  /// Buttons under the titles: acknowledge, silence. The language sets them
  /// black with alert ink. Plain text and icons among them take the plate's
  /// ink.
  final List<Widget> actions;

  /// Part of the layout rather than a full-screen overlay.
  final bool inline;

  /// Minimum height of the inline form. Defaults to 420.
  final double? minHeight;

  /// Horizontal compression of [cjk]; 1.0 turns it off.
  final double squeeze;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final String? id = code;
    final String? latin = en;
    final String? detail = sub;
    final String ticker = marquee ?? <String>[?id, ?latin?.toUpperCase(), ?detail].join('  ///  ');
    final TextStyle tickerStyle = theme.type.mono(13, weight: FontWeight.w600, spacingEm: 0.08, color: c.ink);

    Widget band() => KkHazard(color: c.alert, background: c.bg000, running: true, height: m.space6);

    final Widget plate = KkStrobe(
      period: const Duration(seconds: 1),
      builder: (BuildContext context, bool lit) {
        final Color ink = lit ? c.onFill : c.ink;
        return CustomPaint(
          painter: _PlatePainter(
            fill: lit ? c.alert : c.alertDeep,
            gap: c.bg000,
            ring: c.alert,
            glow: c.glowAlert,
            gapWidth: m.stroke4,
            ringWidth: m.stroke2,
          ),
          child: KkBox(
            padding: EdgeInsets.fromLTRB(m.space12, m.space4, m.space12, m.space6),
            child: KkInk(
              color: ink,
              child: KkColumn(
                shrinkWrap: true,
                gap: m.space2,
                cross: KkCrossAlign.center,
                children: <Widget>[
                  if (id != null) KkText.num(id, size: 13, weight: FontWeight.w600, spacing: 0.08, color: ink),
                  KkText.cjk(cjk, size: inline ? 88 : 120, color: ink, squeeze: squeeze),
                  if (latin != null)
                    KkText.en(latin, size: inline ? 24 : 30, weight: FontWeight.w800, spacing: 0.12, color: ink),
                  if (detail != null)
                    KkText.num(detail, size: 13, weight: FontWeight.w500, height: 1.4, color: ink),
                  if (actions.isNotEmpty)
                    KkBox(
                      padding: EdgeInsets.only(top: m.space2),
                      child: KkRow(shrinkWrap: true, gap: m.space2, children: actions),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return Semantics(
      container: true,
      liveRegion: true,
      label: <String>[?id, cjk, ?latin, ?detail].join(', '),
      child: KkLayers(
        expand: !inline,
        alignment: Alignment.center,
        clip: Clip.hardEdge,
        children: <Widget>[
          KkPositioned.fill(child: KkBox(fill: kkFade(c.alertDeep, 0.72))),
          KkPositioned(left: 0, right: 0, top: m.space6, height: m.space6, child: band()),
          KkPositioned(left: 0, right: 0, bottom: m.space6, height: m.space6, child: band()),
          if (ticker.isNotEmpty) ...<Widget>[
            KkPositioned(
              left: 0,
              right: 0,
              top: m.space12 + m.space2,
              child: KkMarquee(ticker, style: tickerStyle),
            ),
            KkPositioned(
              left: 0,
              right: 0,
              bottom: m.space12 + m.space2,
              child: KkMarquee(ticker, style: tickerStyle, reverse: true),
            ),
          ],
          // Full width; as tall as the screen when it covers it, else as tall
          // as the plate needs (420 at least). The plate sits in the middle.
          KkFillColumn(
            body: KkBox(
              minHeight: inline ? (minHeight ?? 420) : 0,
              padding: EdgeInsets.all(m.space4),
              child: KkColumn(
                shrinkWrap: true,
                main: KkMainAlign.center,
                cross: KkCrossAlign.center,
                children: <Widget>[plate],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatePainter extends CustomPainter {
  const _PlatePainter({
    required this.fill,
    required this.gap,
    required this.ring,
    required this.glow,
    required this.gapWidth,
    required this.ringWidth,
  });

  final Color fill;
  final Color gap;
  final Color ring;
  final KkGlow glow;
  final double gapWidth;
  final double ringWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    if (rect.isEmpty) return;
    // From the outside in: the halo, a 2px alert ring, a 4px black gap, the plate.
    canvas.drawRect(
      rect,
      Paint()
        ..color = kkFade(glow.color, glow.alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, glow.blur / 2),
    );
    canvas.drawRect(rect.inflate(gapWidth + ringWidth), Paint()..color = ring);
    canvas.drawRect(rect.inflate(gapWidth), Paint()..color = gap);
    canvas.drawRect(rect, Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_PlatePainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.gap != gap ||
      oldDelegate.ring != ring ||
      oldDelegate.glow != glow ||
      oldDelegate.gapWidth != gapWidth ||
      oldDelegate.ringWidth != ringWidth;
}

/// Pushes a [KkEmergency] over everything, including dialogs and sheets.
///
/// Tapping outside the plate never closes it. With [dismissible] true the
/// Escape key and the system back gesture close it; otherwise only an action
/// can, by popping the route. Buttons on the plate are black with alert ink:
///
/// ```dart
/// final KkColors c = context.kk.colors;
/// showKkEmergency<void>(
///   context,
///   cjk: '緊急停止',
///   en: 'emergency stop',
///   actions: (BuildContext context) => <Widget>[
///     KkButton(
///       label: 'acknowledge',
///       style: KkPlateStyle(edge: c.bg000, fill: c.bg000, ink: c.alert),
///       onPressed: () => Navigator.of(context).pop(),
///     ),
///   ],
/// );
/// ```
Future<T?> showKkEmergency<T>(
  BuildContext context, {
  String? code,
  required String cjk,
  String? en,
  String? sub,
  String? marquee,
  List<Widget> Function(BuildContext context)? actions,
  bool dismissible = false,
  bool useRootNavigator = true,
  double squeeze = 0.8,
  RouteSettings? settings,
}) {
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    KkPopupRoute<T>(
      dismissible: dismissible,
      label: 'Alarm',
      duration: Duration.zero,
      settings: settings,
      builder: (BuildContext context, Animation<double> animation) => PopScope<T>(
        canPop: dismissible,
        child: KkEmergency(
          code: code,
          cjk: cjk,
          en: en,
          sub: sub,
          marquee: marquee,
          actions: actions?.call(context) ?? const <Widget>[],
          squeeze: squeeze,
        ),
      ),
    ),
  );
}
