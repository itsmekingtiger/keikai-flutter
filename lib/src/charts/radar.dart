import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../layout/layers.dart';
import '../motion/loops.dart';
import '../painting/text.dart';
import '../widgets/icon.dart';
import 'plot.dart';

/// One thing on a radar scope.
@immutable
class KkRadarContact {
  const KkRadarContact({required this.id, required this.bearing, required this.range, this.level, this.label});

  /// Short code written beside the mark (`T-07`).
  final String id;

  /// Degrees clockwise from north (the top of the scope).
  final double bearing;

  /// Distance from the centre, in the same unit as the scope's range.
  final double range;

  /// A contact with a level is drawn as that level's status icon; without one
  /// it is a plain signal mark.
  final KkLevel? level;

  /// Free text for whoever listens to hover and tap.
  final String? label;

  @override
  bool operator ==(Object other) =>
      other is KkRadarContact &&
      other.id == id &&
      other.bearing == bearing &&
      other.range == range &&
      other.level == level &&
      other.label == label;

  @override
  int get hashCode => Object.hash(id, bearing, range, level, label);
}

/// A plan-position scope: range rings, bearing ticks and labels, a beam that
/// sweeps round every four seconds, and contacts placed by bearing and range.
///
/// Contacts carry their status the usual three ways: colour, the status icon
/// drawn on the scope, and (through [footer]) the word. A critical contact
/// blinks; an offline one is the hollow dashed plate. The drawing scales with
/// the scope, like a chart on a wall display.
class KkRadar extends StatefulWidget {
  const KkRadar({
    super.key,
    this.contacts = const <KkRadarContact>[],
    this.range = 100,
    this.rings = 4,
    this.cjk,
    this.en,
    this.meta,
    this.frame = true,
    this.footer,
    this.maxSize = 320,
    this.sweep = true,
    this.sweepPeriod = KkMotion.sweep,
    this.showBearings = true,
    this.showRanges = true,
    this.rangeFormat,
    this.selectedId,
    this.onContactHover,
    this.onContactTap,
    this.boot = true,
    this.semanticLabel,
  });

  final List<KkRadarContact> contacts;

  /// The distance of the outer ring.
  final double range;

  /// Number of range rings, the outer one included.
  final int rings;
  final String? cjk;
  final String? en;
  final String? meta;

  /// Draw the widget frame and head. False leaves just the scope.
  final bool frame;

  /// Legend keys and notes for the foot band.
  final List<Widget>? footer;

  /// The scope's height stops growing at this size when the height is free.
  /// In a parent that fixes the height the scope fits whatever it is given.
  final double maxSize;

  /// Run the sweeping beam.
  final bool sweep;
  final Duration sweepPeriod;

  /// Label the bearings round the rim (`000`, `030` …).
  final bool showBearings;

  /// Label each ring with its range.
  final bool showRanges;
  final String Function(double range)? rangeFormat;

  /// The id of a contact to mark as selected.
  final String? selectedId;

  /// The contact under the pointer, or null when it leaves.
  final ValueChanged<KkRadarContact?>? onContactHover;
  final ValueChanged<KkRadarContact>? onContactTap;

  /// Play the frame's boot wipe when first shown.
  final bool boot;
  final String? semanticLabel;

  @override
  State<KkRadar> createState() => _KkRadarState();
}

/// The scope is drawn in a box of 240 units with the outer ring at radius 100.
class _Scope {
  const _Scope(this.center, this.scale);

  static const double padding = 12;
  static const double view = 240;
  static const double radius = 100;

  final Offset center;
  final double scale;

  static _Scope? of(Size size) {
    final double side = math.min(size.width, size.height) - padding * 2;
    if (!(side > 0) || !side.isFinite) return null;
    return _Scope(size.center(Offset.zero), side / view);
  }

  /// The unit-space position of a contact.
  static Offset place(KkRadarContact contact, double range) {
    final double r = (range > 0 && contact.range.isFinite) ? (contact.range / range).clamp(0.0, 1.0) * radius : 0;
    final double b = contact.bearing.isFinite ? contact.bearing * math.pi / 180 : 0;
    return Offset(math.sin(b) * r, -math.cos(b) * r);
  }

  Offset toCanvas(Offset unit) => center + unit * scale;
}

class _KkRadarState extends State<KkRadar> {
  final ValueNotifier<String?> _hover = ValueNotifier<String?>(null);

  KkRadarContact? _contactAt(Offset position, Size size) {
    final _Scope? scope = _Scope.of(size);
    if (scope == null) return null;
    KkRadarContact? best;
    double bestDistance = math.max(12, 9 * scope.scale);
    for (final KkRadarContact contact in widget.contacts) {
      final double d = (scope.toCanvas(_Scope.place(contact, widget.range)) - position).distance;
      if (d <= bestDistance) {
        bestDistance = d;
        best = contact;
      }
    }
    return best;
  }

  void _setHover(KkRadarContact? contact) {
    if (_hover.value == contact?.id) return;
    _hover.value = contact?.id;
    widget.onContactHover?.call(contact);
  }

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final bool interactive = widget.onContactHover != null || widget.onContactTap != null;
    final bool animated =
        widget.sweep || widget.contacts.any((KkRadarContact contact) => contact.level == KkLevel.critical);

    Widget live(ValueListenable<Duration>? time) => CustomPaint(
      painter: _RadarLivePainter(
        contacts: widget.contacts,
        range: widget.range,
        sweep: widget.sweep,
        sweepPeriod: theme.motion.scaled(widget.sweepPeriod),
        blinkPeriod: theme.motion.scaled(KkMotion.blink),
        selectedId: widget.selectedId,
        theme: theme,
        scaler: scaler,
        time: time,
        hover: _hover,
      ),
    );

    Widget scope = KkLayers(
      expand: true,
      children: <Widget>[
        RepaintBoundary(
          child: KkCanvas(
            naturalWidth: 260,
            aspectRatio: 1,
            maxContentWidth: widget.maxSize,
            painter: _RadarGroundPainter(
              range: widget.range,
              rings: widget.rings,
              showBearings: widget.showBearings,
              showRanges: widget.showRanges,
              rangeFormat: widget.rangeFormat,
              theme: theme,
              scaler: scaler,
            ),
          ),
        ),
        KkPositioned.fill(
          child: RepaintBoundary(
            child: animated
                ? KkLoop(builder: (BuildContext context, ValueListenable<Duration> time) => live(time))
                : live(null),
          ),
        ),
      ],
    );
    if (interactive) {
      scope = KkPlotPointer(
        onMove: (Offset? position, Size size) => _setHover(position == null ? null : _contactAt(position, size)),
        onTap: (Offset position, Size size) {
          final KkRadarContact? contact = _contactAt(position, size);
          if (contact != null) widget.onContactTap?.call(contact);
        },
        child: scope,
      );
    }

    return KkChartFrame(
      frame: widget.frame,
      cjk: widget.cjk,
      en: widget.en,
      meta: widget.meta,
      legend: widget.footer,
      boot: widget.boot,
      semanticLabel: widget.semanticLabel,
      semanticValue: widget.contacts.isEmpty
          ? 'no contacts'
          : <String>[
              for (final KkRadarContact contact in widget.contacts)
                '${contact.id} bearing ${contact.bearing.round()} range ${contact.range.round()}'
                    '${contact.level == null ? '' : ' ${contact.level!.word}'}',
            ].join(', '),
      child: scope,
    );
  }
}

class _RadarGroundPainter extends CustomPainter {
  const _RadarGroundPainter({
    required this.range,
    required this.rings,
    required this.showBearings,
    required this.showRanges,
    required this.rangeFormat,
    required this.theme,
    required this.scaler,
  });

  final double range;
  final int rings;
  final bool showBearings;
  final bool showRanges;
  final String Function(double range)? rangeFormat;
  final KeikaiThemeData theme;
  final TextScaler scaler;

  @override
  void paint(Canvas canvas, Size size) {
    final KkColors c = theme.colors;
    canvas.drawRect(Offset.zero & size, Paint()..color = c.bg000);
    final _Scope? scope = _Scope.of(size);
    if (scope == null) return;
    final double hair = 1 / scope.scale;
    canvas.save();
    canvas.translate(scope.center.dx, scope.center.dy);
    canvas.scale(scope.scale);

    // Axes every 30 degrees.
    final Paint axis = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = hair
      ..color = c.grid;
    for (int i = 0; i < 6; i++) {
      final double a = i * math.pi / 6;
      final Offset d = Offset(math.sin(a), -math.cos(a)) * _Scope.radius;
      canvas.drawLine(-d, d, axis);
    }

    // Range rings; the outer one is the signal frame.
    final int count = math.max(1, rings);
    final Paint ring = Paint()..style = PaintingStyle.stroke;
    for (int i = 1; i <= count; i++) {
      final bool outer = i == count;
      ring
        ..strokeWidth = (outer ? 1.5 : 1) * hair
        ..color = outer ? c.signal : c.line;
      canvas.drawCircle(Offset.zero, _Scope.radius * i / count, ring);
    }

    // Bearing ticks: every 10 degrees, longer every 30.
    final Paint tick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = hair
      ..color = c.inkFaint;
    for (int deg = 0; deg < 360; deg += 10) {
      final double a = deg * math.pi / 180;
      final Offset d = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(d * _Scope.radius, d * (_Scope.radius + (deg % 30 == 0 ? 6 : 3)), tick);
    }

    if (showBearings) {
      final TextStyle style = theme.type.mono(7, weight: FontWeight.w500, color: c.inkDim);
      for (int deg = 0; deg < 360; deg += 30) {
        final double a = deg * math.pi / 180;
        final Offset p = Offset(math.sin(a), -math.cos(a)) * (_Scope.radius + 13);
        kkPaintText(canvas, deg.toString().padLeft(3, '0'), style, p, align: Alignment.center, scaler: scaler);
      }
    }

    if (showRanges && range.isFinite && range > 0) {
      final TextStyle style = theme.type.mono(6, color: c.inkFaint);
      for (int i = 1; i <= count; i++) {
        final double value = range * i / count;
        final String text = rangeFormat?.call(value) ?? (value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(1));
        kkPaintText(canvas, text, style, Offset(2.5, -_Scope.radius * i / count + 2), scaler: scaler);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RadarGroundPainter oldDelegate) =>
      oldDelegate.range != range ||
      oldDelegate.rings != rings ||
      oldDelegate.showBearings != showBearings ||
      oldDelegate.showRanges != showRanges ||
      oldDelegate.rangeFormat != rangeFormat ||
      oldDelegate.theme != theme ||
      oldDelegate.scaler != scaler;
}

class _RadarLivePainter extends CustomPainter {
  _RadarLivePainter({
    required this.contacts,
    required this.range,
    required this.sweep,
    required this.sweepPeriod,
    required this.blinkPeriod,
    required this.selectedId,
    required this.theme,
    required this.scaler,
    required this.time,
    required this.hover,
  }) : super(repaint: Listenable.merge(<Listenable?>[time, hover]));

  final List<KkRadarContact> contacts;
  final double range;
  final bool sweep;
  final Duration sweepPeriod;
  final Duration blinkPeriod;
  final String? selectedId;
  final KeikaiThemeData theme;
  final TextScaler scaler;
  final ValueListenable<Duration>? time;
  final ValueNotifier<String?> hover;

  @override
  void paint(Canvas canvas, Size size) {
    final _Scope? scope = _Scope.of(size);
    if (scope == null) return;
    final KkColors c = theme.colors;
    final Duration now = time?.value ?? Duration.zero;
    final double hair = 1 / scope.scale;
    canvas.save();
    canvas.translate(scope.center.dx, scope.center.dy);
    canvas.scale(scope.scale);

    if (sweep) {
      final double a = kkLoopAt(now, sweepPeriod) * math.pi * 2;
      // The wedge trails the beam by 30 degrees. Canvas angles start at east;
      // bearings start at north, hence the quarter turn.
      final Path wedge = Path()
        ..moveTo(0, 0)
        ..arcTo(
          Rect.fromCircle(center: Offset.zero, radius: _Scope.radius),
          a - math.pi / 2 - math.pi / 6,
          math.pi / 6,
          false,
        )
        ..close();
      canvas.drawPath(wedge, Paint()..color = c.signal.withValues(alpha: c.signal.a * 0.14));
      canvas.drawLine(
        Offset.zero,
        Offset(math.sin(a), -math.cos(a)) * _Scope.radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * hair
          ..color = c.signal,
      );
    }

    final bool dimPhase = time != null && kkPhaseAt(now, blinkPeriod) == 1;
    final TextStyle idStyle = theme.type.mono(6.5, weight: FontWeight.w500, color: c.ink);
    final String? hovered = hover.value;
    for (final KkRadarContact contact in contacts) {
      final Offset p = _Scope.place(contact, range);
      final KkLevel? level = contact.level;
      if (level == null) {
        canvas.drawRect(Rect.fromCenter(center: p, width: 5, height: 5), Paint()..color = c.signal);
      } else {
        Color ink = c.level(level);
        if (level == KkLevel.critical && dimPhase) ink = ink.withValues(alpha: ink.a * 0.2);
        canvas.drawRect(Rect.fromCenter(center: p, width: 12, height: 12), Paint()..color = c.bg000);
        kkPaintIcon(canvas, Rect.fromCenter(center: p, width: 10, height: 10), kkStatusIcon(level), ink);
      }
      if (contact.id.isNotEmpty) {
        kkPaintText(canvas, contact.id, idStyle, p + const Offset(8, -5), align: Alignment.bottomLeft, scaler: scaler);
      }
      if (contact.id == selectedId || contact.id == hovered) {
        canvas.drawRect(
          Rect.fromCenter(center: p, width: 18, height: 18),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 * hair
            ..color = c.focus,
        );
      }
    }

    canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 4, height: 4), Paint()..color = c.signal);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RadarLivePainter oldDelegate) =>
      oldDelegate.contacts != contacts ||
      oldDelegate.range != range ||
      oldDelegate.sweep != sweep ||
      oldDelegate.sweepPeriod != sweepPeriod ||
      oldDelegate.selectedId != selectedId ||
      oldDelegate.theme != theme ||
      oldDelegate.scaler != scaler ||
      oldDelegate.time != time;
}
