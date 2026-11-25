import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../painting/patterns.dart';
import '../painting/text.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';
import 'control_style.dart';

/// A labelled position under a [KkSlider].
@immutable
class KkSliderMark {
  const KkSliderMark(this.value, [this.label]);

  /// Where on the slider's range the mark sits.
  final double value;

  /// Text of the mark. Defaults to the value, formatted like the slider's.
  final String? label;
}

/// A slider on a segmented track.
///
/// The head shows a bilingual label and the live value in mono; the track is
/// 8px segments, lit in signal up to the value; the thumb is an 8 × 22 bar.
/// Drag or tap the track, or use the keyboard: arrows move one step, Page
/// Up / Down ten, Home and End jump to the ends.
///
/// The slider takes the width it is offered; where the width is unbounded
/// (in a row) it is [minWidth] wide.
class KkSlider extends StatefulWidget {
  const KkSlider({
    super.key,
    required this.value,
    this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.min = 0,
    this.max = 100,
    this.divisions,
    this.cjk,
    this.en,
    this.unit,
    this.showValue = true,
    this.format,
    this.fractionDigits = 0,
    this.marks,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    this.minWidth = 200,
  }) : assert(max > min, 'max must be greater than min.'),
       assert(divisions == null || divisions > 0, 'divisions must be positive.');

  final double value;

  /// Called while the value changes. Null disables the slider.
  final ValueChanged<double>? onChanged;

  /// Called when a drag starts.
  final ValueChanged<double>? onChangeStart;

  /// Called when a drag ends.
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;

  /// Number of equal steps between [min] and [max]. Null is continuous.
  final int? divisions;

  /// CJK title in the head.
  final String? cjk;

  /// Latin capitals subtitle in the head.
  final String? en;

  /// Unit shown small after the value: `%`, `dBm`.
  final String? unit;

  /// Show the value in the head.
  final bool showValue;

  /// Formats the value. By default it is shown with [fractionDigits] decimals
  /// and a fixed digit count (leading zeros), so it never changes width.
  final String Function(double value)? format;
  final int fractionDigits;

  /// Labels under the track. The first is left-aligned at its position, the
  /// last right-aligned, the rest centred.
  final List<KkSliderMark>? marks;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Names the slider for screen readers. Defaults to [en].
  final String? semanticLabel;

  /// The slider is never narrower than this (when it has the room).
  final double minWidth;

  /// [value] clamped to [min] … [max] and, with [divisions], snapped to the
  /// nearest step.
  static double snap(double value, {double min = 0, double max = 100, int? divisions}) {
    if (!(max > min)) return min;
    final double v = value.isNaN ? min : value.clamp(min, max);
    if (divisions == null || divisions <= 0) return v;
    final double step = (max - min) / divisions;
    return (min + ((v - min) / step).round() * step).clamp(min, max);
  }

  /// The value under a pointer at [dx] on a track [width] wide with a thumb
  /// [thumb] wide. The thumb's centre follows the pointer.
  static double valueAt(double dx, double width, {double min = 0, double max = 100, int? divisions, double thumb = 8}) {
    final double travel = width - thumb;
    final double fraction = travel <= 0 ? 0 : ((dx - thumb / 2) / travel).clamp(0.0, 1.0);
    return snap(min + fraction * (max - min), min: min, max: max, divisions: divisions);
  }

  /// The default text of a value: [fractionDigits] decimals, padded with
  /// leading zeros to the digit count of the range's larger end.
  static String formatValue(double value, {double min = 0, double max = 100, int fractionDigits = 0}) {
    final int digits = math.max(min.abs(), max.abs()).truncate().toString().length;
    final String body = value.abs().toStringAsFixed(fractionDigits);
    final int whole = body.contains('.') ? body.indexOf('.') : body.length;
    final String padded = whole < digits ? body.padLeft(body.length + digits - whole, '0') : body;
    final bool negative = value < 0 && double.parse(body) != 0;
    return negative ? '-$padded' : padded;
  }

  @override
  State<KkSlider> createState() => _KkSliderState();
}

class _StepIntent extends Intent {
  const _StepIntent(this.steps);

  /// Number of steps to move; `double.infinity` / negative infinity jump to
  /// the ends.
  final double steps;
}

class _KkSliderState extends State<KkSlider> {
  static const double _thumb = 8;
  static const double _rowHeight = 22;
  static const double _trackHeight = 8;

  final GlobalKey _trackKey = GlobalKey();
  bool _hovered = false;
  bool _focused = false;
  bool _dragging = false;

  /// The last value passed to onChanged that the owner has not rebuilt for yet.
  double? _sent;

  static const Map<ShortcutActivator, Intent> _shortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowRight): _StepIntent(1),
    SingleActivator(LogicalKeyboardKey.arrowUp): _StepIntent(1),
    SingleActivator(LogicalKeyboardKey.arrowLeft): _StepIntent(-1),
    SingleActivator(LogicalKeyboardKey.arrowDown): _StepIntent(-1),
    SingleActivator(LogicalKeyboardKey.pageUp): _StepIntent(10),
    SingleActivator(LogicalKeyboardKey.pageDown): _StepIntent(-10),
    SingleActivator(LogicalKeyboardKey.home): _StepIntent(double.negativeInfinity),
    SingleActivator(LogicalKeyboardKey.end): _StepIntent(double.infinity),
  };

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    _StepIntent: CallbackAction<_StepIntent>(onInvoke: (_StepIntent intent) => _stepBy(intent.steps)),
  };

  bool get _live => widget.enabled && widget.onChanged != null;

  double get _value => KkSlider.snap(widget.value, min: widget.min, max: widget.max, divisions: widget.divisions);

  double get _fraction {
    final double range = widget.max - widget.min;
    return range > 0 ? (_value - widget.min) / range : 0;
  }

  /// One keyboard step: a division, or a hundredth of the range.
  double get _step {
    final int? d = widget.divisions;
    return (widget.max - widget.min) / (d ?? 100);
  }

  String _format(double v) =>
      widget.format?.call(v) ??
      KkSlider.formatValue(v, min: widget.min, max: widget.max, fractionDigits: widget.fractionDigits);

  void _emit(double next) {
    if (!_live) return;
    final double v = KkSlider.snap(next, min: widget.min, max: widget.max, divisions: widget.divisions);
    // Several pointer events can arrive before the owner rebuilds, so compare
    // with the last value sent as well as the one last received.
    if (v == (_sent ?? widget.value)) return;
    _sent = v;
    widget.onChanged?.call(v);
  }

  void _stepBy(double steps) {
    if (!_live) return;
    if (steps == double.infinity) {
      _emit(widget.max);
    } else if (steps == double.negativeInfinity) {
      _emit(widget.min);
    } else {
      // Step from the value last sent, so two key presses inside one frame
      // move two steps.
      _emit((_sent ?? _value) + steps * _step);
    }
  }

  double? _valueAt(Offset local) {
    final RenderObject? box = _trackKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return KkSlider.valueAt(
      local.dx,
      box.size.width,
      min: widget.min,
      max: widget.max,
      divisions: widget.divisions,
      thumb: _thumb,
    );
  }

  void _moveTo(Offset local) {
    final double? v = _valueAt(local);
    if (v != null) _emit(v);
  }

  void _dragStart(DragStartDetails details) {
    if (!_live) return;
    _sent = null;
    setState(() => _dragging = true);
    widget.onChangeStart?.call(_value);
    _moveTo(details.localPosition);
  }

  void _dragEnd() {
    if (!_dragging) return;
    setState(() => _dragging = false);
    widget.onChangeEnd?.call(_sent ?? _value);
  }

  @override
  void didUpdateWidget(KkSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The owner has answered (or changed the value itself): start comparing
    // against what it gave us again.
    _sent = null;
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final bool live = _live;
    final KkStates s = KkStateOverride.resolve(
      context,
      KkStates(hovered: _hovered && live, focused: _focused && live, pressed: _dragging && live, enabled: live),
    );
    final String valueText = _format(_value);
    final String? unit = widget.unit;
    final String? cjk = widget.cjk;
    final String? en = widget.en;
    final bool hasHead = cjk != null || en != null || widget.showValue;
    final List<KkSliderMark>? marks = widget.marks;

    final Widget track = FocusableActionDetector(
      enabled: live,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      mouseCursor: live ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      shortcuts: _shortcuts,
      actions: _actions,
      onShowHoverHighlight: (bool value) {
        if (_hovered != value) setState(() => _hovered = value);
      },
      onShowFocusHighlight: (bool value) {
        if (_focused != value) setState(() => _focused = value);
      },
      child: Semantics(
        container: true,
        slider: true,
        enabled: live,
        label: widget.semanticLabel ?? en ?? cjk,
        value: unit == null ? valueText : '$valueText $unit',
        increasedValue: _format(KkSlider.snap(_value + _step, min: widget.min, max: widget.max)),
        decreasedValue: _format(KkSlider.snap(_value - _step, min: widget.min, max: widget.max)),
        onIncrease: live ? () => _stepBy(1) : null,
        onDecrease: live ? () => _stepBy(-1) : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: live ? (TapDownDetails details) => _moveTo(details.localPosition) : null,
          onHorizontalDragStart: live ? _dragStart : null,
          onHorizontalDragUpdate: live ? (DragUpdateDetails details) => _moveTo(details.localPosition) : null,
          onHorizontalDragEnd: live ? (DragEndDetails details) => _dragEnd() : null,
          onHorizontalDragCancel: live ? _dragEnd : null,
          child: KkFocusRing(
            visible: s.focused,
            offset: 4,
            width: m.stroke2,
            child: CustomPaint(
              key: _trackKey,
              size: const Size(0, _rowHeight),
              painter: _SliderPainter(
                fraction: _fraction,
                on: c.signal,
                off: c.signalDim,
                thumb: !live ? c.offline : (s.hovered || s.pressed ? c.signal : c.ink),
                outline: c.bg000,
                pitch: m.pitchFine,
                gap: m.stroke2,
                thumbWidth: _thumb,
                trackHeight: _trackHeight,
              ),
            ),
          ),
        ),
      ),
    );

    return KkBox(
      minWidth: widget.minWidth,
      child: KkColumn(
        shrinkWrap: true,
        gap: m.space2,
        children: <Widget>[
          if (hasHead)
            // The slider's own semantics carry the label and the value.
            ExcludeSemantics(
              child: KkRow(
                gap: m.space2,
                cross: KkCrossAlign.baseline,
                clip: Clip.hardEdge,
                children: <Widget>[
                  if (cjk != null) KkText.cjk(cjk, size: 14, height: 1.55, color: c.ink, squeeze: 0.8),
                  if (en != null)
                    KkText.en(en, size: 11, weight: FontWeight.w600, height: 1.55, spacing: 0.14, color: c.inkDim),
                  const KkSpacer(),
                  if (widget.showValue)
                    KkRow(
                      shrinkWrap: true,
                      cross: KkCrossAlign.baseline,
                      gap: 3,
                      children: <Widget>[
                        KkText.num(valueText, size: 18, weight: FontWeight.w500, color: c.ink),
                        if (unit != null && unit.isNotEmpty)
                          KkText.en(
                            unit,
                            size: 11,
                            weight: FontWeight.w600,
                            spacing: 0.06,
                            color: c.inkDim,
                            upper: false,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          // The row makes the slider take the width it is offered.
          KkRow(children: <Widget>[KkExpanded(child: track)]),
          if (marks != null && marks.isNotEmpty)
            CustomPaint(
              size: const Size(0, 12),
              painter: _MarksPainter(
                positions: <double>[
                  for (final KkSliderMark mark in marks)
                    widget.max > widget.min
                        ? ((mark.value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0)
                        : 0.0,
                ],
                labels: <String>[for (final KkSliderMark mark in marks) mark.label ?? _format(mark.value)],
                style: theme.type.mono(10, color: c.inkFaint),
                scaler: MediaQuery.textScalerOf(context),
              ),
            ),
        ],
      ),
    );
  }
}

class _SliderPainter extends CustomPainter {
  const _SliderPainter({
    required this.fraction,
    required this.on,
    required this.off,
    required this.thumb,
    required this.outline,
    required this.pitch,
    required this.gap,
    required this.thumbWidth,
    required this.trackHeight,
  });

  final double fraction;
  final Color on;
  final Color off;
  final Color thumb;
  final Color outline;
  final double pitch;
  final double gap;
  final double thumbWidth;
  final double trackHeight;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final double f = fraction.clamp(0.0, 1.0);
    final Rect track = Rect.fromLTWH(0, (size.height - trackHeight) / 2, size.width, trackHeight);
    kkPaintSegments(canvas, track, off, pitch: pitch, gap: gap);
    if (f > 0) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(track.left, track.top, track.width * f, track.height));
      kkPaintSegments(canvas, track, on, pitch: pitch, gap: gap);
      canvas.restore();
    }
    final double x = f * math.max(0, size.width - thumbWidth);
    final Rect bar = Rect.fromLTWH(x, 0, thumbWidth, size.height);
    // The thumb's 2px ground-coloured outline lifts it off the segments.
    canvas.drawRect(bar.inflate(2), Paint()..color = outline);
    canvas.drawRect(bar, Paint()..color = thumb);
  }

  @override
  bool shouldRepaint(_SliderPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.on != on ||
      oldDelegate.off != off ||
      oldDelegate.thumb != thumb ||
      oldDelegate.outline != outline ||
      oldDelegate.pitch != pitch ||
      oldDelegate.gap != gap ||
      oldDelegate.thumbWidth != thumbWidth ||
      oldDelegate.trackHeight != trackHeight;
}

class _MarksPainter extends CustomPainter {
  const _MarksPainter({required this.positions, required this.labels, required this.style, required this.scaler});

  /// Where each mark sits, as a share of the width.
  final List<double> positions;
  final List<String> labels;
  final TextStyle style;
  final TextScaler scaler;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    for (int i = 0; i < labels.length; i++) {
      // The last label ends at its position, the first starts there, the
      // rest are centred on theirs.
      final Alignment align = i == labels.length - 1
          ? Alignment.topRight
          : (i == 0 ? Alignment.topLeft : Alignment.topCenter);
      kkPaintText(canvas, labels[i], style, Offset(positions[i] * size.width, 0), align: align, scaler: scaler);
    }
  }

  @override
  bool shouldRepaint(_MarksPainter oldDelegate) =>
      !listEquals(oldDelegate.positions, positions) ||
      !listEquals(oldDelegate.labels, labels) ||
      oldDelegate.style != style ||
      oldDelegate.scaler != scaler;
}
