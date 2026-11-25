import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../layout/flex.dart';
import '../motion/entrances.dart';
import '../motion/scramble.dart';
import '../painting/shapes.dart';
import '../painting/text.dart';
import '../widgets/frame.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';

/// The shell every chart sits in.
///
/// With [frame] it is the standard HUD widget frame: panel ground, 1px line
/// border, head ([cjk], [en], [meta]) and a foot holding the [legend]. Without
/// it the chart is bare (no ground, border or head, only the legend), ready
/// to sit in a panel body.
///
/// Either way the body takes the height it is given: in a parent that fixes
/// the height (a grid cell) the plot fills what the head and legend leave; in
/// a free-height parent the body keeps its natural height.
class KkChartFrame extends StatelessWidget {
  const KkChartFrame({
    super.key,
    this.frame = true,
    this.cjk,
    this.en,
    this.meta,
    this.trailing,
    this.legend,
    this.boot = true,
    this.semanticLabel,
    this.semanticValue,
    required this.child,
  });

  /// Draw the widget frame and head. False leaves the chart bare.
  final bool frame;
  final String? cjk;
  final String? en;

  /// Short mono text at the right of the head.
  final String? meta;

  /// A widget at the right of the head.
  final Widget? trailing;

  /// Legend keys (and notes) for the foot band.
  final List<Widget>? legend;

  /// Play the boot wipe when first shown.
  final bool boot;

  /// What a screen reader calls the chart. Defaults to its titles.
  final String? semanticLabel;

  /// A one-line summary of the data for screen readers.
  final String? semanticValue;

  /// The chart body.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final List<Widget>? keys = (legend == null || legend!.isEmpty) ? null : legend;
    Widget result;
    if (frame) {
      result = KkWidgetFrame(
        cjk: cjk,
        en: en,
        meta: meta,
        trailing: trailing,
        footer: keys,
        boot: boot,
        expandBody: true,
        child: child,
      );
    } else {
      result = keys == null
          ? child
          : KkColumn(
              children: <Widget>[
                KkExpanded(child: child),
                KkWidgetFoot(children: keys),
              ],
            );
      if (boot) result = KkBoot(child: result);
    }
    final String label =
        semanticLabel ?? <String>[?cjk, ?en?.toUpperCase()].join(' ');
    return Semantics(
      container: true,
      image: true,
      label: label.isEmpty ? null : label,
      value: semanticValue,
      child: ExcludeSemantics(child: KkNaturalHeight(child: result)),
    );
  }
}

/// A canvas that sizes itself the way a chart plot does.
///
/// It takes the full width it is offered ([naturalWidth] when the width is
/// unbounded). Its height is the natural height when the height is free and
/// whatever the parent dictates otherwise, so the same plot works in a
/// scrolling column and in a fixed grid cell.
///
/// The natural height is [naturalHeight], or, with [aspectRatio], follows the
/// width: `min(width − insetWidth, maxContentWidth) / aspectRatio +
/// extraHeight`.
class KkCanvas extends StatelessWidget {
  const KkCanvas({
    super.key,
    this.painter,
    this.foregroundPainter,
    this.naturalWidth = 320,
    this.naturalHeight = 140,
    this.aspectRatio,
    this.insetWidth = 0,
    this.maxContentWidth = double.infinity,
    this.extraHeight = 0,
    this.isComplex = false,
    this.willChange = false,
  });

  final CustomPainter? painter;
  final CustomPainter? foregroundPainter;

  /// Width used when the incoming width is unbounded.
  final double naturalWidth;

  /// Height used when the incoming height is free and [aspectRatio] is null.
  final double naturalHeight;

  /// Width over height of the drawing; makes the natural height follow the
  /// width.
  final double? aspectRatio;

  /// Horizontal padding taken off the width before applying [aspectRatio].
  final double insetWidth;

  /// The drawing stops growing beyond this width.
  final double maxContentWidth;

  /// Vertical padding added to the aspect-derived height.
  final double extraHeight;
  final bool isComplex;
  final bool willChange;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: painter,
      foregroundPainter: foregroundPainter,
      isComplex: isComplex,
      willChange: willChange,
      child: _KkPlotSize(
        naturalWidth: naturalWidth,
        naturalHeight: naturalHeight,
        aspectRatio: aspectRatio,
        insetWidth: insetWidth,
        maxContentWidth: maxContentWidth,
        extraHeight: extraHeight,
      ),
    );
  }
}

class _KkPlotSize extends LeafRenderObjectWidget {
  const _KkPlotSize({
    required this.naturalWidth,
    required this.naturalHeight,
    required this.aspectRatio,
    required this.insetWidth,
    required this.maxContentWidth,
    required this.extraHeight,
  });

  final double naturalWidth;
  final double naturalHeight;
  final double? aspectRatio;
  final double insetWidth;
  final double maxContentWidth;
  final double extraHeight;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPlotSize(
    naturalWidth: naturalWidth,
    naturalHeight: naturalHeight,
    aspectRatio: aspectRatio,
    insetWidth: insetWidth,
    maxContentWidth: maxContentWidth,
    extraHeight: extraHeight,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderPlotSize renderObject) {
    renderObject
      ..naturalWidth = naturalWidth
      ..naturalHeight = naturalHeight
      ..aspectRatio = aspectRatio
      ..insetWidth = insetWidth
      ..maxContentWidth = maxContentWidth
      ..extraHeight = extraHeight;
  }
}

class _RenderPlotSize extends RenderBox {
  _RenderPlotSize({
    required double naturalWidth,
    required double naturalHeight,
    required double? aspectRatio,
    required double insetWidth,
    required double maxContentWidth,
    required double extraHeight,
  }) : _naturalWidth = naturalWidth,
       _naturalHeight = naturalHeight,
       _aspectRatio = aspectRatio,
       _insetWidth = insetWidth,
       _maxContentWidth = maxContentWidth,
       _extraHeight = extraHeight;

  double _naturalWidth;
  set naturalWidth(double value) {
    if (value == _naturalWidth) return;
    _naturalWidth = value;
    markNeedsLayout();
  }

  double _naturalHeight;
  set naturalHeight(double value) {
    if (value == _naturalHeight) return;
    _naturalHeight = value;
    markNeedsLayout();
  }

  double? _aspectRatio;
  set aspectRatio(double? value) {
    if (value == _aspectRatio) return;
    _aspectRatio = value;
    markNeedsLayout();
  }

  double _insetWidth;
  set insetWidth(double value) {
    if (value == _insetWidth) return;
    _insetWidth = value;
    markNeedsLayout();
  }

  double _maxContentWidth;
  set maxContentWidth(double value) {
    if (value == _maxContentWidth) return;
    _maxContentWidth = value;
    markNeedsLayout();
  }

  double _extraHeight;
  set extraHeight(double value) {
    if (value == _extraHeight) return;
    _extraHeight = value;
    markNeedsLayout();
  }

  double _heightFor(double width) {
    final double? ratio = _aspectRatio;
    if (ratio == null || !(ratio > 0) || !ratio.isFinite) return _naturalHeight;
    final double content = math.max(0, math.min(width - _insetWidth, _maxContentWidth));
    final double h = content / ratio + _extraHeight;
    return h.isFinite ? h : _naturalHeight;
  }

  Size _sizeFor(BoxConstraints c) {
    final double w = c.hasBoundedWidth ? c.maxWidth : c.constrainWidth(_naturalWidth);
    return Size(w, c.constrainHeight(_heightFor(w)));
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => _naturalWidth;

  @override
  double computeMinIntrinsicHeight(double width) => _heightFor(width.isFinite ? width : _naturalWidth);

  @override
  double computeMaxIntrinsicHeight(double width) => _heightFor(width.isFinite ? width : _naturalWidth);

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sizeFor(constraints);

  @override
  void performLayout() => size = _sizeFor(constraints);
}

/// Reports where the pointer is over a plot: hover with a mouse, press and
/// drag with a finger, and taps.
///
/// It listens to raw pointer events, so a finger scrubbing along a chart does
/// not have to win against the scroll view around it.
class KkPlotPointer extends StatefulWidget {
  const KkPlotPointer({super.key, required this.onMove, this.onTap, this.cursor = MouseCursor.defer, required this.child});

  /// Called with the pointer position (in the child's coordinates) and the
  /// child's size while the pointer is over the plot, and with a null position
  /// when it leaves or lifts.
  final void Function(Offset? position, Size size) onMove;

  /// Called when a press is released close to where it began.
  final void Function(Offset position, Size size)? onTap;
  final MouseCursor cursor;
  final Widget child;

  @override
  State<KkPlotPointer> createState() => _KkPlotPointerState();
}

class _KkPlotPointerState extends State<KkPlotPointer> {
  Offset? _down;

  Size get _size => context.size ?? Size.zero;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      onHover: (PointerHoverEvent event) => widget.onMove(event.localPosition, _size),
      onExit: (PointerExitEvent event) => widget.onMove(null, _size),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (PointerDownEvent event) {
          _down = event.localPosition;
          widget.onMove(event.localPosition, _size);
        },
        onPointerMove: (PointerMoveEvent event) => widget.onMove(event.localPosition, _size),
        onPointerUp: (PointerUpEvent event) {
          final Offset? down = _down;
          _down = null;
          if (down != null && (down - event.localPosition).distance <= kTouchSlop) {
            widget.onTap?.call(event.localPosition, _size);
          }
          if (event.kind != PointerDeviceKind.mouse) widget.onMove(null, _size);
        },
        onPointerCancel: (PointerCancelEvent event) {
          _down = null;
          widget.onMove(null, _size);
        },
        child: widget.child,
      ),
    );
  }
}

/// One line of a chart tooltip: an optional colour key, a name and a value.
@immutable
class KkTipRow {
  const KkTipRow({this.color, required this.name, required this.value, this.box = false});

  final Color? color;
  final String name;
  final String value;

  /// A 10×10 box key (bars) instead of a 12×3 line key (lines).
  final bool box;
}

/// Paints the chart tooltip beside [anchor], flipped and nudged so it stays
/// inside [bounds]: a bg-200 plate with a 1px signal border, a dim title line
/// and one row per series with its value in semibold at the right.
///
/// Returns the rectangle it covered.
Rect kkPaintChartTip(
  Canvas canvas,
  Rect bounds,
  Offset anchor, {
  String? title,
  List<KkTipRow> rows = const <KkTipRow>[],
  required KeikaiThemeData theme,
  TextScaler scaler = TextScaler.noScaling,
  double gap = 12,
}) {
  if (bounds.isEmpty || (title == null && rows.isEmpty)) return Rect.zero;
  final KkColors c = theme.colors;
  final TextStyle base = theme.type.mono(11, height: 1.55, color: c.ink);
  final TextStyle dim = base.copyWith(color: c.inkDim);
  final TextStyle strong = base.copyWith(fontWeight: FontWeight.w600);
  const double padH = 8;
  const double padV = 6;
  const double keyGap = 6;
  const double valueGap = 12;

  final TextPainter? titlePainter = title == null ? null : kkLayoutText(title, dim, scaler: scaler);
  final List<TextPainter> names = <TextPainter>[
    for (final KkTipRow r in rows) kkLayoutText(r.name, base, scaler: scaler),
  ];
  final List<TextPainter> values = <TextPainter>[
    for (final KkTipRow r in rows) kkLayoutText(r.value, strong, scaler: scaler),
  ];
  double content = titlePainter?.width ?? 0;
  double rowsHeight = 0;
  for (int i = 0; i < rows.length; i++) {
    final double key = rows[i].color == null ? 0 : (rows[i].box ? 10 : 12) + keyGap;
    content = math.max(content, key + names[i].width + valueGap + values[i].width);
    rowsHeight += math.max(names[i].height, values[i].height);
  }
  final double width = math.max(132, content + padH * 2 + 2).ceilToDouble();
  final double height = (padV * 2 + 2 + (titlePainter?.height ?? 0) + rowsHeight).ceilToDouble();

  double left = anchor.dx + gap;
  if (left + width > bounds.right) left = anchor.dx - gap - width;
  left = left.clamp(bounds.left, math.max(bounds.left, bounds.right - width));
  final double top = (anchor.dy - height / 2).clamp(bounds.top, math.max(bounds.top, bounds.bottom - height));
  final Rect rect = Rect.fromLTWH(left.roundToDouble(), top.roundToDouble(), width, height);

  kkPaintSurface(canvas, rect, fill: c.bg200, edge: c.signal, edgeWidth: theme.metrics.stroke1);
  final double x0 = rect.left + 1 + padH;
  final double x1 = rect.right - 1 - padH;
  double y = rect.top + 1 + padV;
  if (titlePainter != null) {
    titlePainter.paint(canvas, Offset(x0, y));
    y += titlePainter.height;
  }
  final Paint keyPaint = Paint();
  for (int i = 0; i < rows.length; i++) {
    final double lineHeight = math.max(names[i].height, values[i].height);
    double x = x0;
    final Color? key = rows[i].color;
    if (key != null) {
      keyPaint.color = key;
      final double kw = rows[i].box ? 10 : 12;
      final double kh = rows[i].box ? 10 : 3;
      canvas.drawRect(Rect.fromLTWH(x, y + (lineHeight - kh) / 2, kw, kh), keyPaint);
      x += kw + keyGap;
    }
    names[i].paint(canvas, Offset(x, y + (lineHeight - names[i].height) / 2));
    values[i].paint(canvas, Offset(x1 - values[i].width, y + (lineHeight - values[i].height) / 2));
    y += lineHeight;
  }
  titlePainter?.dispose();
  for (final TextPainter p in names) {
    p.dispose();
  }
  for (final TextPainter p in values) {
    p.dispose();
  }
  return rect;
}

/// Hands the scrambling form of [text] to [builder]: the digits churn for
/// 0.46s whenever the text changes and settle from the front.
///
/// It is `KkScramble` for text that is drawn on a canvas instead of laid out
/// as a widget (a gauge's value, for example).
class KkScrambleBuilder extends StatefulWidget {
  const KkScrambleBuilder({
    super.key,
    required this.text,
    this.duration = KkMotion.scramble,
    this.steps = 10,
    this.onMount = true,
    this.letters = false,
    this.enabled = true,
    required this.builder,
  });

  final String text;
  final Duration duration;

  /// How many times the noise changes during the scramble.
  final int steps;

  /// Scramble when first shown as well as on change.
  final bool onMount;

  /// Scramble letters too, not only digits.
  final bool letters;
  final bool enabled;

  /// [shown] is [text] once settled.
  final Widget Function(BuildContext context, String shown) builder;

  @override
  State<KkScrambleBuilder> createState() => _KkScrambleBuilderState();
}

class _KkScrambleBuilderState extends State<KkScrambleBuilder> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, value: 1)
    ..addListener(_onTick);
  int _step = -1;
  int _generation = 0;
  bool _started = false;

  void _onTick() {
    final int s = (_controller.value * widget.steps).floor();
    if (s != _step) setState(() => _step = s);
  }

  void _run() {
    if (!widget.enabled || !KeikaiTheme.motionOf(context)) {
      _controller.value = 1;
      return;
    }
    _generation++;
    _controller.duration = KeikaiTheme.of(context).motion.scaled(widget.duration);
    _controller.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (widget.onMount) _run();
    }
  }

  @override
  void didUpdateWidget(KkScrambleBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _run();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double p = _controller.value;
    final String shown = p >= 1
        ? widget.text
        : kkScrambleText(
            widget.text,
            p,
            step: (p * widget.steps).floor(),
            seed: _generation * 31 + widget.text.length,
            letters: widget.letters,
          );
    return widget.builder(context, shown);
  }
}

/// Paints a crisp 1px horizontal line from [x0] to [x1] at [y].
void kkPaintHLine(Canvas canvas, double x0, double x1, double y, Color color, {double width = 1}) {
  if (x1 <= x0 || color.a <= 0) return;
  canvas.drawRect(Rect.fromLTWH(x0, y.roundToDouble(), x1 - x0, width), Paint()..color = color);
}

/// Paints a crisp 1px vertical line from [y0] to [y1] at [x].
void kkPaintVLine(Canvas canvas, double x, double y0, double y1, Color color, {double width = 1}) {
  if (y1 <= y0 || color.a <= 0) return;
  canvas.drawRect(Rect.fromLTWH(x.roundToDouble(), y0, width, y1 - y0), Paint()..color = color);
}

/// Keyboard access for a plot: makes it focusable, shows the focus ring for
/// keyboard focus, and turns arrow keys, Home, End, Enter and Escape into
/// callbacks so a chart can move its cursor from the keyboard.
class KkPlotFocus extends StatefulWidget {
  const KkPlotFocus({
    super.key,
    this.enabled = true,
    required this.onStep,
    this.onJump,
    this.onActivate,
    this.onDismiss,
    this.onFocusChange,
    this.ringOffset = -2,
    required this.child,
  });

  /// Whether the plot can take focus at all.
  final bool enabled;

  /// An arrow key was pressed: [dx] is −1 (left) or 1 (right), [dy] is −1 (up)
  /// or 1 (down).
  final void Function(int dx, int dy) onStep;

  /// Home ([toEnd] false) or End ([toEnd] true) was pressed.
  final void Function(bool toEnd)? onJump;

  /// Enter or Space was pressed.
  final VoidCallback? onActivate;

  /// Escape was pressed, or keyboard focus left the plot.
  final VoidCallback? onDismiss;
  final ValueChanged<bool>? onFocusChange;

  /// Where the 2px focus ring sits; negative is inside the plot.
  final double ringOffset;
  final Widget child;

  @override
  State<KkPlotFocus> createState() => _KkPlotFocusState();
}

class _PlotStepIntent extends Intent {
  const _PlotStepIntent(this.dx, this.dy);

  final int dx;
  final int dy;
}

class _PlotJumpIntent extends Intent {
  const _PlotJumpIntent(this.toEnd);

  final bool toEnd;
}

class _KkPlotFocusState extends State<KkPlotFocus> {
  bool _ring = false;

  static const Map<ShortcutActivator, Intent> _shortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowLeft): _PlotStepIntent(-1, 0),
    SingleActivator(LogicalKeyboardKey.arrowRight): _PlotStepIntent(1, 0),
    SingleActivator(LogicalKeyboardKey.arrowUp): _PlotStepIntent(0, -1),
    SingleActivator(LogicalKeyboardKey.arrowDown): _PlotStepIntent(0, 1),
    SingleActivator(LogicalKeyboardKey.home): _PlotJumpIntent(false),
    SingleActivator(LogicalKeyboardKey.end): _PlotJumpIntent(true),
    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
  };

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    _PlotStepIntent: CallbackAction<_PlotStepIntent>(
      onInvoke: (_PlotStepIntent intent) {
        widget.onStep(intent.dx, intent.dy);
        return null;
      },
    ),
    _PlotJumpIntent: CallbackAction<_PlotJumpIntent>(
      onInvoke: (_PlotJumpIntent intent) {
        widget.onJump?.call(intent.toEnd);
        return null;
      },
    ),
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (ActivateIntent intent) {
        widget.onActivate?.call();
        return null;
      },
    ),
    DismissIntent: CallbackAction<DismissIntent>(
      onInvoke: (DismissIntent intent) {
        widget.onDismiss?.call();
        return null;
      },
    ),
  };

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return FocusableActionDetector(
      shortcuts: _shortcuts,
      actions: _actions,
      onShowFocusHighlight: (bool value) {
        if (_ring != value) setState(() => _ring = value);
      },
      onFocusChange: (bool focused) {
        widget.onFocusChange?.call(focused);
        if (!focused) widget.onDismiss?.call();
      },
      child: KkFocusRing(visible: _ring, offset: widget.ringOffset, child: widget.child),
    );
  }
}

/// The six-step intensity ramp as a legend key: six 14×8 swatches 2px apart,
/// from nearly black to hot, with a label at each end.
class KkRampKey extends StatelessWidget {
  const KkRampKey({super.key, this.low, this.high});

  /// Label before the darkest swatch (the low end of the scale).
  final String? low;

  /// Label after the brightest swatch.
  final String? high;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final String? lo = low;
    final String? hi = high;
    return KkRow(
      shrinkWrap: true,
      gap: theme.metrics.space2,
      children: <Widget>[
        if (lo != null) KkText.num(lo, size: 11, color: c.inkDim),
        CustomPaint(size: const Size(6 * 14 + 5 * 2, 8), painter: _RampPainter(c.ramp)),
        if (hi != null) KkText.num(hi, size: 11, color: c.inkDim),
      ],
    );
  }
}

class _RampPainter extends CustomPainter {
  const _RampPainter(this.ramp);

  final List<Color> ramp;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();
    for (int i = 0; i < ramp.length; i++) {
      paint.color = ramp[i];
      canvas.drawRect(Rect.fromLTWH(i * 16.0, 0, 14, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_RampPainter oldDelegate) => !listEquals(oldDelegate.ramp, ramp);
}

/// The ramp step (0 to 5) for [value] in the range [low] to [high]. Null and
/// non-finite values, and a range with no extent, give step 0.
int kkRampStep(double? value, double low, double high) {
  if (value == null || !value.isFinite || !(high > low)) return 0;
  return ((value - low) / (high - low) * 6).floor().clamp(0, 5);
}

/// Lets its child keep its natural height unless the parent dictates one.
///
/// When the incoming height is fixed the child gets exactly that. Otherwise
/// the child is measured with a free height and keeps that height if the
/// parent allows it; if it does not fit the allowed range the child is laid
/// out at the nearest allowed height instead of overflowing.
///
/// Charts use it so the same widget fills a grid cell and sits at its natural
/// height in a scrolling page, a row or an aligned box.
class KkNaturalHeight extends SingleChildRenderObjectWidget {
  const KkNaturalHeight({super.key, super.child});

  @override
  RenderKkNaturalHeight createRenderObject(BuildContext context) => RenderKkNaturalHeight();
}

/// The render object behind [KkNaturalHeight].
class RenderKkNaturalHeight extends RenderProxyBox {
  RenderKkNaturalHeight([super.child]);

  BoxConstraints _free(BoxConstraints c) => BoxConstraints(minWidth: c.minWidth, maxWidth: c.maxWidth);

  ({Size size, BoxConstraints used}) _resolve(BoxConstraints constraints, ChildLayouter layoutChild) {
    final RenderBox c = child!;
    if (constraints.hasTightHeight) return (size: layoutChild(c, constraints), used: constraints);
    final BoxConstraints free = _free(constraints);
    final Size natural = layoutChild(c, free);
    final double target = constraints.constrainHeight(natural.height);
    if ((target - natural.height).abs() < 0.01) return (size: natural, used: free);
    final BoxConstraints forced = constraints.tighten(height: target);
    return (size: layoutChild(c, forced), used: forced);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (child == null) return constraints.smallest;
    return constraints.constrain(_resolve(constraints, ChildLayoutHelper.dryLayoutChild).size);
  }

  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    final RenderBox? c = child;
    if (c == null) return null;
    return c.getDryBaseline(_resolve(constraints, ChildLayoutHelper.dryLayoutChild).used, baseline);
  }

  @override
  void performLayout() {
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    size = constraints.constrain(_resolve(constraints, ChildLayoutHelper.layoutChild).size);
  }
}
