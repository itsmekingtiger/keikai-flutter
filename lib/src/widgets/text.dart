import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import '../foundation/typography.dart';
import '../layout/flex.dart';

enum _Voice { raw, cjk, en, num, body }

/// Text in one of the four KEIKAI voices.
///
/// * [KkText.cjk]: 漢字 and Hangul titles in the heavy Mincho display face.
///   With `squeeze` the glyphs are compressed to 80% width (長体), the way
///   every component title is set.
/// * [KkText.en]: Latin capitals in the extra-condensed label face. The text
///   is upper-cased for you.
/// * [KkText.num]: numbers, codes and times in tabular monospace.
/// * [KkText.body]: explanatory sentences.
///
/// The colour defaults to the current text colour.
class KkText extends StatelessWidget {
  /// Text with an explicit [style] (or the ambient default style).
  const KkText(
    this.data, {
    super.key,
    this.style,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  }) : _voice = _Voice.raw,
       size = null,
       weight = null,
       height = null,
       spacing = null,
       squeeze = null,
       upper = false;

  /// A CJK title in the display voice.
  const KkText.cjk(
    this.data, {
    super.key,
    this.size = 14,
    this.height = 1.0,
    this.spacing = 0,
    this.color,
    this.squeeze,
    this.textAlign,
    this.maxLines = 1,
    this.overflow,
    this.softWrap = false,
    this.style,
  }) : _voice = _Voice.cjk,
       weight = null,
       upper = false;

  /// A Latin capitals label.
  const KkText.en(
    this.data, {
    super.key,
    this.size = 11,
    this.weight = FontWeight.w700,
    this.height = 1.0,
    this.spacing = 0.1,
    this.color,
    this.upper = true,
    this.textAlign,
    this.maxLines = 1,
    this.overflow,
    this.softWrap = false,
    this.style,
  }) : _voice = _Voice.en,
       squeeze = null;

  /// A number, code or time in tabular monospace.
  const KkText.num(
    this.data, {
    super.key,
    this.size = 12,
    this.weight = FontWeight.w400,
    this.height = 1.0,
    this.spacing = 0,
    this.color,
    this.textAlign,
    this.maxLines = 1,
    this.overflow,
    this.softWrap = false,
    this.style,
  }) : _voice = _Voice.num,
       squeeze = null,
       upper = false;

  /// A body sentence.
  const KkText.body(
    this.data, {
    super.key,
    this.size = 14,
    this.weight = FontWeight.w400,
    this.height = 1.55,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.style,
  }) : _voice = _Voice.body,
       spacing = null,
       squeeze = null,
       upper = false;

  final String data;
  final _Voice _voice;

  /// Font size in px (before the theme's type scale).
  final double? size;
  final FontWeight? weight;

  /// Line height as a multiple of the font size.
  final double? height;

  /// Tracking in em.
  final double? spacing;
  final Color? color;

  /// Horizontal compression of a CJK title. 0.8 is the house 長体.
  final double? squeeze;

  /// Upper-case the text (labels only).
  final bool upper;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  /// Merged over the voice's style.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkTypography type = theme.type;
    final TextStyle ambient = DefaultTextStyle.of(context).style;
    final Color ink = color ?? style?.color ?? ambient.color ?? theme.colors.ink;
    TextStyle resolved = switch (_voice) {
      _Voice.raw => ambient,
      _Voice.cjk => type.display(size!, height: height!, spacingEm: spacing!),
      _Voice.en => type.label(size!, weight: weight!, height: height!, spacingEm: spacing!),
      _Voice.num => type.mono(size!, weight: weight!, height: height!, spacingEm: spacing!),
      _Voice.body => type.body(size!, weight: weight!, height: height!),
    };
    if (style != null) resolved = resolved.merge(style);
    resolved = resolved.copyWith(color: ink);
    Widget text = Text(
      upper ? data.toUpperCase() : data,
      style: resolved,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow ?? (softWrap == false ? TextOverflow.clip : null),
      softWrap: softWrap,
    );
    final double? s = squeeze;
    if (s != null && s != 1.0) text = KkSqueeze(scaleX: s, child: text);
    return text;
  }
}

/// A CJK title beside its Latin capitals subtitle, sharing a baseline.
///
/// Titles are written in two languages throughout KEIKAI: 電源系統 + POWER.
class KkLabel extends StatelessWidget {
  const KkLabel({
    super.key,
    this.cjk,
    this.en,
    this.cjkSize = 14,
    this.enSize = 11,
    this.enWeight = FontWeight.w600,
    this.enSpacing = 0.14,
    this.cjkColor,
    this.enColor,
    this.gap,
    this.squeeze = 0.8,
  });

  final String? cjk;
  final String? en;
  final double cjkSize;
  final double enSize;
  final FontWeight enWeight;
  final double enSpacing;

  /// Defaults to ink.
  final Color? cjkColor;

  /// Defaults to dim ink.
  final Color? enColor;

  /// Defaults to 8.
  final double? gap;

  /// Compression of the CJK part; 1.0 turns it off.
  final double squeeze;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final String? c = cjk;
    final String? e = en;
    return KkRow(
      shrinkWrap: true,
      cross: KkCrossAlign.baseline,
      gap: gap ?? theme.metrics.space2,
      children: <Widget>[
        if (c != null && c.isNotEmpty)
          KkText.cjk(c, size: cjkSize, color: cjkColor ?? theme.colors.ink, squeeze: squeeze),
        if (e != null && e.isNotEmpty)
          KkText.en(e, size: enSize, weight: enWeight, spacing: enSpacing, color: enColor ?? theme.colors.inkDim),
      ],
    );
  }
}

/// Sets the current text (and icon) colour for the subtree.
class KkInk extends StatelessWidget {
  const KkInk({super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    style: TextStyle(color: color),
    child: child,
  );
}

/// Compresses its child horizontally and takes only the compressed width, so
/// the text that follows closes up: the 長体 of KEIKAI titles.
class KkSqueeze extends SingleChildRenderObjectWidget {
  const KkSqueeze({super.key, this.scaleX = 0.8, super.child}) : assert(scaleX > 0);

  final double scaleX;

  @override
  RenderKkSqueeze createRenderObject(BuildContext context) => RenderKkSqueeze(scaleX: scaleX);

  @override
  void updateRenderObject(BuildContext context, RenderKkSqueeze renderObject) => renderObject.scaleX = scaleX;
}

/// The render object behind [KkSqueeze].
class RenderKkSqueeze extends RenderProxyBox {
  RenderKkSqueeze({double scaleX = 0.8, RenderBox? child}) : _scaleX = scaleX, super(child);

  double _scaleX;
  double get scaleX => _scaleX;
  set scaleX(double value) {
    if (value == _scaleX) return;
    _scaleX = value;
    markNeedsLayout();
  }

  BoxConstraints _childConstraints(BoxConstraints c) => BoxConstraints(
    minWidth: c.minWidth / _scaleX,
    maxWidth: c.maxWidth.isFinite ? c.maxWidth / _scaleX : double.infinity,
    minHeight: c.minHeight,
    maxHeight: c.maxHeight,
  );

  @override
  double computeMinIntrinsicWidth(double height) => (child?.getMinIntrinsicWidth(height) ?? 0) * _scaleX;

  @override
  double computeMaxIntrinsicWidth(double height) => (child?.getMaxIntrinsicWidth(height) ?? 0) * _scaleX;

  @override
  double computeMinIntrinsicHeight(double width) => child?.getMinIntrinsicHeight(width / _scaleX) ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) => child?.getMaxIntrinsicHeight(width / _scaleX) ?? 0;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final RenderBox? c = child;
    if (c == null) return constraints.smallest;
    final Size s = c.getDryLayout(_childConstraints(constraints));
    return constraints.constrain(Size(s.width * _scaleX, s.height));
  }

  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) =>
      child?.getDryBaseline(_childConstraints(constraints), baseline);

  @override
  void performLayout() {
    final RenderBox? c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(_childConstraints(constraints), parentUsesSize: true);
    size = constraints.constrain(Size(c.size.width * _scaleX, c.size.height));
  }

  Matrix4 get _transform => Matrix4.diagonal3Values(_scaleX, 1, 1);

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) => transform.multiply(_transform);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) => super.hitTestChildren(result, position: transformed),
    );
  }

  final LayerHandle<TransformLayer> _layer = LayerHandle<TransformLayer>();

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      _layer.layer = null;
      return;
    }
    _layer.layer = context.pushTransform(needsCompositing, offset, _transform, super.paint, oldLayer: _layer.layer);
  }

  @override
  void dispose() {
    _layer.layer = null;
    super.dispose();
  }
}

/// Upright vertical text (縦書き): the spine of a panel and the stem of an
/// L-shaped heading.
///
/// Characters are stacked top to bottom in a single column, each centred in
/// the column.
class KkTate extends StatelessWidget {
  const KkTate(
    this.data, {
    super.key,
    this.size = 14,
    this.color,
    this.columnWidth,
    this.spacing = 0,
  });

  final String data;

  /// Font size in px (before the theme's type scale).
  final double size;

  /// Defaults to the current text colour.
  final Color? color;

  /// Width of the column; defaults to the font size.
  final double? columnWidth;

  /// Extra space after each character, in em.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final Color c = color ?? DefaultTextStyle.of(context).style.color ?? theme.colors.ink;
    return Semantics(
      label: data,
      child: ExcludeSemantics(
        child: _KkTateLeaf(
          data: data,
          style: theme.type.display(size, color: c),
          columnWidth: columnWidth,
          spacing: spacing,
          scaler: MediaQuery.textScalerOf(context),
        ),
      ),
    );
  }
}

class _KkTateLeaf extends LeafRenderObjectWidget {
  const _KkTateLeaf({
    required this.data,
    required this.style,
    required this.columnWidth,
    required this.spacing,
    required this.scaler,
  });

  final String data;
  final TextStyle style;
  final double? columnWidth;
  final double spacing;
  final TextScaler scaler;

  @override
  RenderKkTate createRenderObject(BuildContext context) =>
      RenderKkTate(text: data, style: style, columnWidth: columnWidth, spacing: spacing, scaler: scaler);

  @override
  void updateRenderObject(BuildContext context, RenderKkTate renderObject) {
    renderObject
      ..text = data
      ..style = style
      ..columnWidth = columnWidth
      ..spacing = spacing
      ..scaler = scaler;
  }
}

/// The render object behind [KkTate].
class RenderKkTate extends RenderBox {
  RenderKkTate({
    required String text,
    required TextStyle style,
    double? columnWidth,
    double spacing = 0,
    TextScaler scaler = TextScaler.noScaling,
  }) : _text = text,
       _style = style,
       _columnWidth = columnWidth,
       _spacing = spacing,
       _scaler = scaler;

  String _text;
  String get text => _text;
  set text(String value) {
    if (value == _text) return;
    _text = value;
    _invalidate();
  }

  TextStyle _style;
  TextStyle get style => _style;
  set style(TextStyle value) {
    if (value == _style) return;
    _style = value;
    _invalidate();
  }

  double? _columnWidth;
  double? get columnWidth => _columnWidth;
  set columnWidth(double? value) {
    if (value == _columnWidth) return;
    _columnWidth = value;
    markNeedsLayout();
  }

  double _spacing;
  double get spacing => _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  TextScaler _scaler;
  TextScaler get scaler => _scaler;
  set scaler(TextScaler value) {
    if (value == _scaler) return;
    _scaler = value;
    _invalidate();
  }

  List<TextPainter>? _painters;

  void _invalidate() {
    _disposePainters();
    markNeedsLayout();
  }

  void _disposePainters() {
    final List<TextPainter>? ps = _painters;
    if (ps != null) {
      for (final TextPainter p in ps) {
        p.dispose();
      }
    }
    _painters = null;
  }

  List<TextPainter> _ensurePainters() {
    return _painters ??= <TextPainter>[
      for (final String ch in _text.characters)
        TextPainter(
          text: TextSpan(text: ch, style: _style.copyWith(height: 1.0, letterSpacing: 0)),
          textDirection: TextDirection.ltr,
          textScaler: _scaler,
          maxLines: 1,
        )..layout(),
    ];
  }

  double get _em => _scaler.scale(_style.fontSize ?? 14);
  double get _advance => _em * (1 + _spacing);

  Size _natural() {
    final List<TextPainter> ps = _ensurePainters();
    double w = _columnWidth ?? _em;
    if (_columnWidth == null) {
      for (final TextPainter p in ps) {
        w = math.max(w, p.width);
      }
    }
    return Size(w, ps.length * _advance);
  }

  @override
  double computeMinIntrinsicWidth(double height) => _natural().width;

  @override
  double computeMaxIntrinsicWidth(double height) => _natural().width;

  @override
  double computeMinIntrinsicHeight(double width) => _natural().height;

  @override
  double computeMaxIntrinsicHeight(double width) => _natural().height;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(_natural());

  /// A vertical column of characters has no horizontal baseline. Saying so
  /// keeps a baseline-aligned row that is measured without being laid out
  /// from asserting.
  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) => null;

  @override
  void performLayout() => size = constraints.constrain(_natural());

  @override
  void paint(PaintingContext context, Offset offset) {
    final List<TextPainter> ps = _ensurePainters();
    final Canvas canvas = context.canvas;
    final Size natural = _natural();
    final bool overflow = natural.height > size.height + 0.5 || natural.width > size.width + 0.5;
    if (overflow) {
      canvas.save();
      canvas.clipRect(offset & size);
    }
    final double em = _em;
    for (int i = 0; i < ps.length; i++) {
      final TextPainter p = ps[i];
      p.paint(canvas, offset + Offset((size.width - p.width) / 2, i * _advance + (em - p.height) / 2));
    }
    if (overflow) canvas.restore();
  }

  @override
  void dispose() {
    _disposePainters();
    super.dispose();
  }
}
