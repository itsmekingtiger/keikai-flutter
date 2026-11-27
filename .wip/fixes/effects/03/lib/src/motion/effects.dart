import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../painting/patterns.dart';
import '../painting/text.dart';
import 'loops.dart';

/// A hazard band: 45° stripes in the level colour (or signal) over black.
///
/// It runs (the stripes travel right, one period every 0.9s) only when
/// [running] is true, which the language reserves for a critical alarm.
class KkHazard extends StatelessWidget {
  const KkHazard({
    super.key,
    this.level,
    this.color,
    this.background,
    this.running = false,
    this.pitch,
    this.width,
    this.height,
  });

  final KkLevel? level;

  /// Stripe colour. Defaults to the level colour, or signal.
  final Color? color;

  /// Colour between the stripes. Defaults to the screen ground; pass
  /// transparent to let the surface show through.
  final Color? background;
  final bool running;

  /// Width of one stripe. Defaults to the theme's hazard pitch (12).
  final double? pitch;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final Color a = color ?? theme.colors.level(level);
    final Color b = background ?? theme.colors.bg000;
    final double p = pitch ?? theme.metrics.pitchHazard;
    Widget paint(ValueListenable<Duration>? time) => CustomPaint(
      size: Size(width ?? p * 4, height ?? p * 2),
      // The loop clock already runs at the theme's time scale.
      painter: _HazardPainter(a: a, b: b, pitch: p, time: time, period: KkMotion.hazard),
    );
    final Widget child = running
        ? KkLoop(builder: (BuildContext context, ValueListenable<Duration> time) => paint(time))
        : paint(null);
    return SizedBox(
      width: width,
      height: height,
      child: ExcludeSemantics(child: child),
    );
  }
}

class _HazardPainter extends CustomPainter {
  _HazardPainter({required this.a, required this.b, required this.pitch, required this.time, required this.period})
    : super(repaint: time);

  final Color a;
  final Color b;
  final double pitch;
  final ValueListenable<Duration>? time;
  final Duration period;

  @override
  void paint(Canvas canvas, Size size) {
    final ValueListenable<Duration>? t = time;
    // One square tile per stripe period, so the shift loops without a seam.
    final double tile = pitch * 2 * math.sqrt2;
    final double shift = t == null ? 0 : kkLoopAt(t.value, period) * tile;
    kkPaintStripes(
      canvas,
      Offset.zero & size,
      a: a,
      b: b.a > 0 ? b : null,
      width: pitch,
      period: pitch * 2,
      shift: shift,
      tiled: t != null,
    );
  }

  @override
  bool shouldRepaint(_HazardPainter oldDelegate) =>
      oldDelegate.a != a || oldDelegate.b != b || oldDelegate.pitch != pitch || oldDelegate.time != time;
}

/// Text that scrolls sideways in an endless loop: the bands of a full-screen
/// alarm.
///
/// The band takes all the width it is given. Where the width is free (in a
/// row, in a sideways scroll view) it is one repetition wide: the text and the
/// [gap] after it.
class KkMarquee extends StatelessWidget {
  const KkMarquee(
    this.text, {
    super.key,
    this.style,
    this.period = const Duration(seconds: 14),
    this.reverse = false,
    this.gap = 32,
  });

  final String text;

  /// Defaults to 13px semibold mono in ink.
  final TextStyle? style;

  /// Time for the text to travel the length of one repetition.
  final Duration period;
  final bool reverse;

  /// Space between repetitions.
  final double gap;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final TextStyle s = style ?? theme.type.mono(13, weight: FontWeight.w600, spacingEm: 0.08, color: theme.colors.ink);
    // The painter fills the band up to its right edge, so the band needs one:
    // where no width is given, it is one repetition wide.
    final double unit = kkMeasureText(text, s) + gap;
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: LimitedBox(
          maxWidth: unit > 0 && unit.isFinite ? unit : 0,
          child: KkLoop(
            builder: (BuildContext context, ValueListenable<Duration> time) => CustomPaint(
              size: Size(double.infinity, (s.fontSize ?? 13) * (s.height ?? 1.0)),
              painter: _MarqueePainter(
                text: text,
                style: s,
                time: time,
                // The loop clock already runs at the theme's time scale.
                period: period,
                reverse: reverse,
                gap: gap,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarqueePainter extends CustomPainter {
  _MarqueePainter({
    required this.text,
    required this.style,
    required this.time,
    required this.period,
    required this.reverse,
    required this.gap,
  }) : super(repaint: time);

  final String text;
  final TextStyle style;
  final ValueListenable<Duration> time;
  final Duration period;
  final bool reverse;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    // A band without a right edge could never be filled.
    if (text.isEmpty || size.width <= 0 || !size.width.isFinite) return;
    final TextPainter tp = kkLayoutText(text, style);
    final double unit = tp.width + gap;
    if (unit <= 0) {
      tp.dispose();
      return;
    }
    double shift = kkLoopAt(time.value, period) * unit;
    if (reverse) shift = unit - shift;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final double y = (size.height - tp.height) / 2;
    for (double x = -shift; x < size.width; x += unit) {
      tp.paint(canvas, Offset(x, y));
    }
    canvas.restore();
    tp.dispose();
  }

  @override
  bool shouldRepaint(_MarqueePainter oldDelegate) =>
      oldDelegate.text != text ||
      oldDelegate.style != style ||
      oldDelegate.reverse != reverse ||
      oldDelegate.gap != gap ||
      oldDelegate.period != period;
}

/// Display-panel texture drawn over the child: CRT scan lines, a line that
/// sweeps down every 5s, and flickering noise at 9% opacity.
///
/// The language keeps these for large display panels and for "no signal".
///
/// The child keeps its place in the tree whatever is switched on, so a
/// texture can come and go without the child losing its state.
class KkCrt extends StatelessWidget {
  const KkCrt({super.key, this.scanlines = true, this.sweep = false, this.noise = false, required this.child});

  final bool scanlines;
  final bool sweep;
  final bool noise;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final KkColors c = KeikaiTheme.of(context).colors;
    final bool moving = sweep || noise;
    // The same widgets for every set of textures: a child that moved to
    // another depth would be built anew. A loop that is not enabled starts no
    // ticker, and a CustomPaint without a painter draws nothing.
    return KkLoop(
      enabled: moving,
      builder: (BuildContext context, ValueListenable<Duration> time) => CustomPaint(
        foregroundPainter: scanlines || moving
            ? _CrtPainter(
                scanColor: scanlines ? kkFade(c.bg000, 0.5) : null,
                sweepColor: sweep ? c.signal : null,
                noise: noise,
                time: moving ? time : null,
              )
            : null,
        child: child,
      ),
    );
  }
}

class _CrtPainter extends CustomPainter {
  _CrtPainter({required this.scanColor, required this.sweepColor, required this.noise, required this.time})
    : super(repaint: time);

  final Color? scanColor;
  final Color? sweepColor;
  final bool noise;
  final ValueListenable<Duration>? time;

  static ui.Image? _noiseTile;
  static const List<Offset> _noiseOffsets = <Offset>[Offset.zero, Offset(-37, 21), Offset(19, -43), Offset(-11, 33)];

  static ui.Image _tile() {
    final ui.Image? cached = _noiseTile;
    if (cached != null) return cached;
    const int n = 120;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final math.Random random = math.Random(7);
    final Paint paint = Paint();
    for (int y = 0; y < n; y++) {
      for (int x = 0; x < n; x++) {
        final double v = random.nextDouble();
        if (v < 0.42) continue;
        paint.color = Color.fromRGBO(255, 255, 255, (v - 0.42) / 0.58);
        canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
      }
    }
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = picture.toImageSync(n, n);
    picture.dispose();
    return _noiseTile = image;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    if (rect.isEmpty) return;
    final Duration now = time?.value ?? Duration.zero;
    canvas.save();
    canvas.clipRect(rect);
    if (noise) {
      final Offset o = _noiseOffsets[kkPhaseAt(now, const Duration(milliseconds: 450), phases: 4)];
      final Float64List m = Matrix4.translationValues(o.dx, o.dy, 0).storage;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.ImageShader(_tile(), TileMode.repeated, TileMode.repeated, m)
          ..color = const Color.fromRGBO(255, 255, 255, 0.09),
      );
    }
    final Color? scan = scanColor;
    if (scan != null) KkScanPattern(color: scan).paint(canvas, rect);
    final Color? sw = sweepColor;
    if (sw != null) {
      final double y = kkLoopAt(now, const Duration(seconds: 5)) * size.height;
      final Rect line = Rect.fromLTWH(0, y, size.width, 2);
      canvas.drawRect(
        line,
        Paint()
          ..color = kkFade(sw, 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawRect(line, Paint()..color = kkFade(sw, 0.55));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CrtPainter oldDelegate) =>
      oldDelegate.scanColor != scanColor ||
      oldDelegate.sweepColor != sweepColor ||
      oldDelegate.noise != noise ||
      oldDelegate.time != time;
}

/// Glitches its child for half a second and flashes red three times whenever
/// [trigger] changes. `KeikaiApp` wraps the whole screen in one and fires it
/// at the moment the condition turns to alert.
class KkGlitch extends StatefulWidget {
  const KkGlitch({super.key, required this.trigger, this.flash = true, required this.child});

  /// The glitch plays when this value changes (not when first shown).
  final Object? trigger;

  /// Also flash the alert colour over the child three times.
  final bool flash;
  final Widget child;

  @override
  State<KkGlitch> createState() => _KkGlitchState();
}

class _KkGlitchState extends State<KkGlitch> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, value: 1);

  @override
  void didUpdateWidget(KkGlitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger && KeikaiTheme.motionOf(context)) {
      _controller.duration = KeikaiTheme.of(context).motion.scaled(KkMotion.flash);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _KkGlitchBox(
      progress: _controller,
      flashColor: widget.flash ? KeikaiTheme.of(context).colors.alert : null,
      child: widget.child,
    );
  }
}

class _KkGlitchBox extends SingleChildRenderObjectWidget {
  const _KkGlitchBox({required this.progress, required this.flashColor, super.child});

  final Animation<double> progress;
  final Color? flashColor;

  @override
  RenderKkGlitch createRenderObject(BuildContext context) => RenderKkGlitch(progress: progress, flashColor: flashColor);

  @override
  void updateRenderObject(BuildContext context, RenderKkGlitch renderObject) {
    renderObject
      ..progress = progress
      ..flashColor = flashColor;
  }
}

/// The render object behind [KkGlitch].
///
/// [progress] runs over 0.7s: the first 0.5s displace, skew and slice the
/// child in five steps; the whole 0.7s carries three hard flashes.
class RenderKkGlitch extends RenderProxyBox {
  RenderKkGlitch({required Animation<double> progress, Color? flashColor, RenderBox? child})
    : _progress = progress,
      _flashColor = flashColor,
      super(child);

  Animation<double> _progress;
  Animation<double> get progress => _progress;
  set progress(Animation<double> value) {
    if (value == _progress) return;
    if (attached) _progress.removeListener(markNeedsPaint);
    _progress = value;
    if (attached) _progress.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  Color? _flashColor;
  Color? get flashColor => _flashColor;
  set flashColor(Color? value) {
    if (value == _flashColor) return;
    _flashColor = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _progress.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _progress.removeListener(markNeedsPaint);
    super.detach();
  }

  bool get _active => _progress.value < 1;

  static const List<double> _stops = <double>[0, 0.2, 0.4, 0.6, 0.8, 1];
  static const List<double> _shift = <double>[0, -7, 6, -3, 2, 0];
  static const List<double> _skewStops = <double>[0, 0.2, 0.4, 1];
  static const List<double> _skew = <double>[0, -5, 0, 0];

  final LayerHandle<TransformLayer> _transformLayer = LayerHandle<TransformLayer>();
  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    if (!_active) {
      _transformLayer.layer = null;
      _clipLayer.layer = null;
      super.paint(context, offset);
      return;
    }
    final double p = _progress.value;
    // The displacement uses the first 5/7 of the timeline (0.5s of 0.7s).
    final double g = (p * 7 / 5).clamp(0.0, 1.0);
    final double dx = kkKeyframes(g, _stops, _shift, steps: 5);
    final double skew = kkKeyframes(g, _skewStops, _skew, steps: 5) * math.pi / 180;
    Rect clip = Offset.zero & size;
    if (g >= 0.3 && g < 0.5) {
      clip = Rect.fromLTRB(0, size.height * 0.12, size.width, size.height * (1 - 0.52));
    } else if (g >= 0.5 && g < 0.7) {
      clip = Rect.fromLTRB(0, size.height * 0.58, size.width, size.height * (1 - 0.09));
    }
    final Matrix4 m = Matrix4.identity()
      ..setEntry(0, 1, math.tan(skew))
      ..setEntry(0, 3, dx);
    _transformLayer.layer = context.pushTransform(needsCompositing, offset, m, (PaintingContext c, Offset o) {
      _clipLayer.layer = c.pushClipRect(needsCompositing, o, clip, super.paint, oldLayer: _clipLayer.layer);
    }, oldLayer: _transformLayer.layer);

    final Color? flash = _flashColor;
    if (flash != null) {
      final bool on = (p < 0.17) || (p >= 0.34 && p < 0.51) || (p >= 0.68 && p < 0.85);
      if (on) {
        context.canvas.drawRect(
          offset & size,
          Paint()
            ..color = kkFade(flash, 0.6)
            ..blendMode = BlendMode.screen,
        );
      }
    }
  }

  @override
  void dispose() {
    _transformLayer.layer = null;
    _clipLayer.layer = null;
    super.dispose();
  }
}
