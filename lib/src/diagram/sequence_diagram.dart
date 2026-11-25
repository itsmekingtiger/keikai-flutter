import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/level.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../foundation/typography.dart';
import '../motion/entrances.dart';
import '../painting/shapes.dart';
import '../painting/text.dart';
import '../widgets/frame.dart';
import 'metrics.dart';

/// One party of a [KkSequenceDiagram]: a column with a code plate on top and
/// a lifeline under it.
@immutable
class KkSequenceParticipant {
  const KkSequenceParticipant(this.id, {this.code, this.cjk, this.level});

  /// Key the messages refer to.
  final String id;

  /// The code on the plate, such as `SEC-04`. Defaults to [id].
  final String? code;

  /// A CJK title over the plate.
  final String? cjk;

  /// Colours the plate and the lifeline; offline dims the lifeline.
  final KkLevel? level;

  /// The code that is drawn.
  String get text {
    final String? c = code;
    return c == null || c.isEmpty ? id : c;
  }

  @override
  bool operator ==(Object other) =>
      other is KkSequenceParticipant &&
      other.id == id &&
      other.code == code &&
      other.cjk == cjk &&
      other.level == level;

  @override
  int get hashCode => Object.hash(id, code, cjk, level);
}

/// How a message is drawn.
enum KkSequenceMessageKind {
  /// A request: solid line, filled head. The receiver becomes active until it
  /// replies.
  call,

  /// An answer: dashed line, open head. It ends the sender's activation.
  reply,

  /// A signal that expects no answer: solid line, open head.
  async,
}

/// One row of a [KkSequenceDiagram]: a message or a divider.
@immutable
sealed class KkSequenceEntry {
  const KkSequenceEntry();
}

/// A message from one participant to another (or to itself).
class KkSequenceMessage extends KkSequenceEntry {
  const KkSequenceMessage(
    this.from,
    this.to,
    this.label, {
    this.kind = KkSequenceMessageKind.call,
    this.level,
    this.note,
  });

  /// Id of the sender.
  final String from;

  /// Id of the receiver. The same id as [from] draws a loop.
  final String to;

  /// Text over the arrow.
  final String label;
  final KkSequenceMessageKind kind;

  /// Colours the arrow.
  final KkLevel? level;

  /// Mono text in the right margin, such as a time.
  final String? note;

  @override
  bool operator ==(Object other) =>
      other is KkSequenceMessage &&
      other.from == from &&
      other.to == to &&
      other.label == label &&
      other.kind == kind &&
      other.level == level &&
      other.note == note;

  @override
  int get hashCode => Object.hash(from, to, label, kind, level, note);
}

/// A ruled line across all lifelines with a bilingual label: the start of a
/// phase.
class KkSequenceDivider extends KkSequenceEntry {
  const KkSequenceDivider({this.cjk, this.en, this.code});

  final String? cjk;
  final String? en;

  /// A short code before the label, such as `PH-02`.
  final String? code;

  @override
  bool operator ==(Object other) =>
      other is KkSequenceDivider && other.cjk == cjk && other.en == en && other.code == code;

  @override
  int get hashCode => Object.hash(cjk, en, code);
}

/// A sequence diagram: who tells whom what, in time order from top to bottom.
///
/// Participants are code plates with dashed lifelines. A call is a solid
/// arrow with a filled head and makes its receiver active (a bar on the
/// lifeline) until that receiver replies; a reply is dashed; an async signal
/// has an open head; a message to oneself is a loop of right angles. Rows are
/// numbered on the left, and a message's [KkSequenceMessage.note] sits in the
/// right margin. Messages are drawn one after another when the diagram first
/// appears.
///
/// The diagram stretches its columns to the width it is given and shrinks as
/// a whole when there is too little.
class KkSequenceDiagram extends StatelessWidget {
  const KkSequenceDiagram({
    super.key,
    required this.participants,
    required this.entries,
    this.cjk,
    this.en,
    this.meta,
    this.level,
    this.framed = true,
    this.legend = true,
    this.numbered = true,
    this.rowHeight = 32,
    this.minColumnGap = 120,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    this.animate = true,
  }) : assert(rowHeight >= 24),
       assert(minColumnGap > 0);

  final List<KkSequenceParticipant> participants;

  /// Messages and dividers, top to bottom.
  final List<KkSequenceEntry> entries;

  /// CJK title of the head band.
  final String? cjk;

  /// Latin capitals subtitle of the head band.
  final String? en;

  /// Mono text at the right of the head band. Defaults to the message count.
  final String? meta;

  /// Level of the whole widget (the frame).
  final KkLevel? level;

  /// Wrap the diagram in the HUD widget frame.
  final bool framed;

  /// Show the CALL / REPLY / ASYNC legend in the foot band.
  final bool legend;

  /// Number the messages in the left margin.
  final bool numbered;

  /// Height of one message row.
  final double rowHeight;

  /// Least distance between two lifelines.
  final double minColumnGap;
  final EdgeInsets padding;

  /// Draw the messages one after another on entry.
  final bool animate;

  String _summary() {
    final Map<String, String> names = <String, String>{
      for (final KkSequenceParticipant p in participants) p.id: p.text,
    };
    final StringBuffer b = StringBuffer('Sequence, ${participants.length} participants');
    for (final KkSequenceEntry e in entries) {
      if (e is KkSequenceMessage) {
        b.write('. ${names[e.from] ?? e.from} to ${names[e.to] ?? e.to}: ${e.label}');
      }
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final int messages = entries.whereType<KkSequenceMessage>().length;
    final _SequenceLayout natural = _SequenceLayout.natural(this, theme.type.scale);
    final Duration total = Duration(
      milliseconds: 300 + (messages <= 1 ? 0 : (math.min(90.0, 1800 / (messages - 1)) * (messages - 1)).round()) + 800,
    );
    final Widget plot = Semantics(
      label: _summary(),
      child: ExcludeSemantics(
        child: KkOneShot(
          duration: total,
          enabled: animate,
          builder: (BuildContext context, Animation<double> progress, bool done, Widget? child) => _SequencePlot(
            diagram: this,
            natural: natural,
            colors: c,
            type: theme.type,
            progress: progress,
            messages: messages,
          ),
        ),
      ),
    );
    if (!framed) return plot;
    return KkWidgetFrame(
      cjk: cjk,
      en: en,
      meta: meta ?? '${messages.toString().padLeft(2, '0')} MSG',
      level: level,
      boot: animate,
      footer: legend
          ? const <Widget>[
              KkWidgetKey(label: 'CALL', swatch: _ArrowSwatch(KkSequenceMessageKind.call)),
              KkWidgetKey(label: 'REPLY', swatch: _ArrowSwatch(KkSequenceMessageKind.reply)),
              KkWidgetKey(label: 'ASYNC', swatch: _ArrowSwatch(KkSequenceMessageKind.async)),
            ]
          : null,
      child: plot,
    );
  }
}

/// Where everything of a sequence diagram sits, in its own unscaled space.
class _SequenceLayout {
  _SequenceLayout._({
    required this.size,
    required this.scale,
    required this.xs,
    required this.plateWidths,
    required this.headTop,
    required this.plateTop,
    required this.plateHeight,
    required this.firstRow,
    required this.rowHeight,
    required this.left,
    required this.noteWidth,
    required this.textScale,
    required this.naturalGap,
    required this.padding,
    required this.rows,
  });

  factory _SequenceLayout.natural(KkSequenceDiagram d, double typeScale) {
    final int n = d.participants.length;
    final double ts = typeScale;
    final Map<String, int> index = <String, int>{for (int i = 0; i < n; i++) d.participants[i].id: i};
    final List<double> plates = <double>[
      for (final KkSequenceParticipant p in d.participants)
        math.max(64, (KkNodeMetrics.monoWidth(p.text, 11 * ts) + 24).ceilToDouble()),
    ];
    final bool anyCjk = d.participants.any((KkSequenceParticipant p) => p.cjk != null && p.cjk!.isNotEmpty);
    double noteWidth = 0;
    double gap = d.minColumnGap;
    double selfReach = 0;
    for (final KkSequenceEntry e in d.entries) {
      if (e is! KkSequenceMessage) continue;
      final String? note = e.note;
      if (note != null && note.isNotEmpty) {
        noteWidth = math.max(noteWidth, KkNodeMetrics.monoWidth(note, 10 * ts) + 12);
      }
      final int? a = index[e.from];
      final int? b = index[e.to];
      if (a == null || b == null) continue;
      final double label = KkNodeMetrics.monoWidth(e.label, 10 * ts);
      if (a == b) {
        if (a == n - 1) {
          selfReach = math.max(selfReach, 36 + label + 8);
        } else {
          gap = math.max(gap, 36 + label + 16);
        }
      } else {
        gap = math.max(gap, (label + 32) / (a - b).abs());
      }
    }
    gap = (gap / 4).ceilToDouble() * 4;
    final double left = d.padding.left + (d.numbered ? 28 * ts : 0);
    final double first = left + (n == 0 ? 0 : plates.first / 2);
    final List<double> xs = <double>[for (int i = 0; i < n; i++) first + gap * i];
    final double lastHalf = n == 0 ? 0 : plates.last / 2;
    final double width = (n == 0 ? left : xs.last + math.max(lastHalf, selfReach)) + noteWidth + d.padding.right;
    final double headTop = d.padding.top;
    final double plateTop = headTop + (anyCjk ? 18 * ts : 0);
    const double plateHeight = 28;
    final double firstRow = plateTop + plateHeight + 28;
    final List<double> rows = <double>[];
    double y = firstRow;
    for (final KkSequenceEntry e in d.entries) {
      rows.add(y);
      y += e is KkSequenceMessage && e.from == e.to ? d.rowHeight + 8 : d.rowHeight;
    }
    final double height = (d.entries.isEmpty ? firstRow : y - d.rowHeight + 28) + d.padding.bottom;
    return _SequenceLayout._(
      size: Size(math.max(width, 1), math.max(height, 1)),
      scale: 1,
      xs: xs,
      plateWidths: plates,
      headTop: headTop,
      plateTop: plateTop,
      plateHeight: plateHeight,
      firstRow: firstRow,
      rowHeight: d.rowHeight,
      left: left,
      noteWidth: noteWidth,
      textScale: ts,
      naturalGap: gap,
      padding: d.padding,
      rows: rows,
    );
  }

  final Size size;

  /// Shrink factor when the diagram is given less width than it needs.
  final double scale;
  final List<double> xs;
  final List<double> plateWidths;
  final double headTop;
  final double plateTop;
  final double plateHeight;
  final double firstRow;
  final double rowHeight;
  final double left;
  final double noteWidth;
  final double textScale;
  final double naturalGap;
  final EdgeInsets padding;

  /// The line of each entry.
  final List<double> rows;

  /// This layout stretched (or shrunk as a whole) to [width].
  _SequenceLayout fitted(double width) {
    if (!width.isFinite || width <= 0 || (width - size.width).abs() < 0.5) return this;
    if (width < size.width) return _copy(scale: width / size.width);
    // More room: spread the lifelines.
    final int n = xs.length;
    if (n < 2) return _copy(size: Size(width, size.height));
    final double extra = (width - size.width) / (n - 1);
    return _copy(
      size: Size(width, size.height),
      xs: <double>[for (int i = 0; i < n; i++) xs[i] + extra * i],
    );
  }

  _SequenceLayout _copy({Size? size, double? scale, List<double>? xs}) => _SequenceLayout._(
    size: size ?? this.size,
    scale: scale ?? this.scale,
    xs: xs ?? this.xs,
    plateWidths: plateWidths,
    headTop: headTop,
    plateTop: plateTop,
    plateHeight: plateHeight,
    firstRow: firstRow,
    rowHeight: rowHeight,
    left: left,
    noteWidth: noteWidth,
    textScale: textScale,
    naturalGap: naturalGap,
    padding: padding,
    rows: rows,
  );
}

/// The drawing of a sequence diagram as a box of its own: its natural width
/// when free, spread out when given more, shrunk as a whole when given less.
/// It can be measured without being laid out, so it may stand in a row that
/// sizes itself from its children.
class _SequencePlot extends LeafRenderObjectWidget {
  const _SequencePlot({
    required this.diagram,
    required this.natural,
    required this.colors,
    required this.type,
    required this.progress,
    required this.messages,
  });

  final KkSequenceDiagram diagram;
  final _SequenceLayout natural;
  final KkColors colors;
  final KkTypography type;
  final Animation<double> progress;
  final int messages;

  @override
  _RenderSequencePlot createRenderObject(BuildContext context) =>
      _RenderSequencePlot(diagram, natural, colors, type, progress, messages);

  @override
  void updateRenderObject(BuildContext context, _RenderSequencePlot renderObject) {
    renderObject.update(diagram, natural, colors, type, progress, messages);
  }
}

class _RenderSequencePlot extends RenderBox {
  _RenderSequencePlot(this._diagram, this._natural, this._colors, this._type, this._progress, this._messages);

  KkSequenceDiagram _diagram;
  _SequenceLayout _natural;
  KkColors _colors;
  KkTypography _type;
  Animation<double> _progress;
  int _messages;
  _SequenceLayout? _layout;

  void update(
    KkSequenceDiagram diagram,
    _SequenceLayout natural,
    KkColors colors,
    KkTypography type,
    Animation<double> progress,
    int messages,
  ) {
    if (!identical(progress, _progress)) {
      if (attached) _progress.removeListener(markNeedsPaint);
      _progress = progress;
      if (attached) _progress.addListener(markNeedsPaint);
    }
    _diagram = diagram;
    _natural = natural;
    _colors = colors;
    _type = type;
    _messages = messages;
    // The natural layout is rebuilt with the widget, so lay out again.
    markNeedsLayout();
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

  _SequenceLayout _fitted(BoxConstraints constraints) =>
      _natural.fitted(constraints.hasBoundedWidth ? constraints.maxWidth : _natural.size.width);

  static Size _sizeOf(_SequenceLayout layout, BoxConstraints constraints) =>
      constraints.constrain(layout.size * layout.scale);

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => _natural.size.width;

  @override
  double computeMinIntrinsicHeight(double width) {
    final _SequenceLayout layout = _natural.fitted(width);
    return layout.size.height * layout.scale;
  }

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sizeOf(_fitted(constraints), constraints);

  // A drawing has no line of text to sit on.
  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) => null;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => null;

  @override
  void performLayout() {
    final _SequenceLayout layout = _fitted(constraints);
    _layout = layout;
    size = _sizeOf(layout, constraints);
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final _SequenceLayout? layout = _layout;
    if (layout == null || size.isEmpty) return;
    final Canvas canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    _SequencePainter(_diagram, layout, _colors, _type, _progress, _messages).paint(canvas, size);
    canvas.restore();
  }
}

class _SequencePainter {
  _SequencePainter(this.diagram, this.layout, this.colors, this.type, this.progress, this.messages);

  final KkSequenceDiagram diagram;
  final _SequenceLayout layout;
  final KkColors colors;
  final KkTypography type;
  final Animation<double> progress;
  final int messages;

  double get _k => layout.textScale / type.scale;

  /// Progress (0 to 1, in 16 steps) of message number [index].
  double _wipe(int index) {
    final double t = progress.value;
    if (t >= 1) return 1;
    final double gap = messages <= 1 ? 0 : math.min(90.0, 1800 / (messages - 1));
    final double total = 300 + gap * math.max(0, messages - 1) + 800;
    return const KkSteps(16).transform(((t * total - 300 - gap * index) / 800).clamp(0.0, 1.0));
  }

  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(layout.scale);
    final List<KkSequenceParticipant> ps = diagram.participants;
    final Map<String, int> index = <String, int>{for (int i = 0; i < ps.length; i++) ps[i].id: i};
    final double bottom = layout.size.height - layout.padding.bottom;
    final double plateBottom = layout.plateTop + layout.plateHeight;

    // Lifelines.
    for (int i = 0; i < ps.length; i++) {
      final Color lifeline = ps[i].level == KkLevel.offline ? colors.offline : colors.line;
      final Path line = Path()
        ..moveTo(layout.xs[i], plateBottom)
        ..lineTo(layout.xs[i], bottom - 3);
      canvas.drawPath(
        kkDashPath(line, const <double>[3, 3]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = lifeline,
      );
      canvas.drawRect(Rect.fromCenter(center: Offset(layout.xs[i], bottom - 3), width: 5, height: 5), Paint()..color = lifeline);
    }

    // Activations: a call makes its receiver active until that receiver replies.
    final List<({int column, int from, int to, int depth})> bars = <({int column, int from, int to, int depth})>[];
    final Map<int, List<int>> open = <int, List<int>>{};
    final List<int> messageNumber = List<int>.filled(diagram.entries.length, -1);
    int number = 0;
    for (int r = 0; r < diagram.entries.length; r++) {
      final KkSequenceEntry e = diagram.entries[r];
      if (e is! KkSequenceMessage) continue;
      messageNumber[r] = number++;
      final int? a = index[e.from];
      final int? b = index[e.to];
      if (a == null || b == null || a == b) continue;
      if (e.kind == KkSequenceMessageKind.reply) {
        final List<int>? stack = open[a];
        if (stack != null && stack.isNotEmpty) {
          final int start = stack.removeLast();
          bars.add((column: a, from: start, to: r, depth: stack.length));
        }
      } else if (e.kind == KkSequenceMessageKind.call) {
        (open[b] ??= <int>[]).add(r);
      }
    }
    for (final MapEntry<int, List<int>> e in open.entries) {
      for (int d = 0; d < e.value.length; d++) {
        bars.add((column: e.key, from: e.value[d], to: diagram.entries.length - 1, depth: d));
      }
    }
    for (final ({int column, int from, int to, int depth}) bar in bars) {
      if (_wipe(messageNumber[bar.from]) < 1) continue;
      final double x = layout.xs[bar.column] + bar.depth * 4;
      final Color edge = colors.level(ps[bar.column].level, fallback: colors.signal);
      final Rect rect = Rect.fromLTRB(x - 4, layout.rows[bar.from], x + 4, layout.rows[bar.to] + (bar.to == bar.from ? 12 : 0));
      canvas.drawRect(rect, Paint()..color = edge);
      canvas.drawRect(rect.deflate(1), Paint()..color = colors.bg300);
    }

    // Heads.
    for (int i = 0; i < ps.length; i++) {
      final KkSequenceParticipant p = ps[i];
      final Color lv = colors.level(p.level, fallback: colors.signal);
      final Rect plate = Rect.fromCenter(
        center: Offset(layout.xs[i], layout.plateTop + layout.plateHeight / 2),
        width: layout.plateWidths[i],
        height: layout.plateHeight,
      );
      kkPaintSurface(canvas, plate, shape: const KkShape.plate(6), fill: colors.bg100, edge: lv);
      kkPaintText(
        canvas,
        p.text,
        type.mono(11 * _k, weight: FontWeight.w600, spacingEm: 0.06, color: p.level == KkLevel.offline ? colors.offline : colors.ink),
        plate.center,
        align: Alignment.center,
      );
      final String? cjk = p.cjk;
      if (cjk != null && cjk.isNotEmpty) {
        final TextPainter tp = kkLayoutText(cjk, type.display(13 * _k, color: colors.ink));
        canvas.save();
        canvas.translate(layout.xs[i] - tp.width * 0.8 / 2, layout.headTop + (14 * layout.textScale - tp.height) / 2);
        canvas.scale(0.8, 1);
        tp.paint(canvas, Offset.zero);
        canvas.restore();
        tp.dispose();
      }
    }

    // Rows.
    for (int r = 0; r < diagram.entries.length; r++) {
      final KkSequenceEntry e = diagram.entries[r];
      final double y = layout.rows[r];
      switch (e) {
        case KkSequenceDivider():
          _paintDivider(canvas, e, y);
        case KkSequenceMessage():
          _paintMessage(canvas, e, y, messageNumber[r], index, bars, r);
      }
    }
    canvas.restore();
  }

  void _paintDivider(Canvas canvas, KkSequenceDivider e, double y) {
    final double right = layout.size.width - layout.padding.right;
    canvas.drawRect(Rect.fromLTRB(layout.padding.left, y, right, y + 1), Paint()..color = colors.line);
    double x = layout.padding.left;
    final List<(String, TextStyle, double)> parts = <(String, TextStyle, double)>[
      if (e.code != null && e.code!.isNotEmpty) (e.code!, type.mono(10 * _k, weight: FontWeight.w500, color: colors.signal), 1),
      if (e.cjk != null && e.cjk!.isNotEmpty) (e.cjk!, type.display(12 * _k, color: colors.ink), 0.8),
      if (e.en != null && e.en!.isNotEmpty)
        (e.en!.toUpperCase(), type.label(10 * _k, weight: FontWeight.w600, spacingEm: 0.16, color: colors.inkDim), 1),
    ];
    if (parts.isEmpty) return;
    final List<TextPainter> painters = <TextPainter>[for (final (String, TextStyle, double) p in parts) kkLayoutText(p.$1, p.$2)];
    double width = 12;
    for (int i = 0; i < parts.length; i++) {
      width += painters[i].width * parts[i].$3 + (i > 0 ? 6 : 0);
    }
    final Rect chip = Rect.fromLTWH(x, y - 9, width, 19);
    canvas.drawRect(chip, Paint()..color = colors.bg200);
    canvas.drawRect(Rect.fromLTWH(chip.left, chip.top, 2, chip.height), Paint()..color = colors.signal);
    x += 8;
    for (int i = 0; i < parts.length; i++) {
      final TextPainter tp = painters[i];
      canvas.save();
      canvas.translate(x, chip.center.dy - tp.height / 2);
      canvas.scale(parts[i].$3, 1);
      tp.paint(canvas, Offset.zero);
      canvas.restore();
      x += tp.width * parts[i].$3 + 6;
      tp.dispose();
    }
  }

  void _paintMessage(
    Canvas canvas,
    KkSequenceMessage e,
    double y,
    int number,
    Map<String, int> index,
    List<({int column, int from, int to, int depth})> bars,
    int row,
  ) {
    final int? a = index[e.from];
    final int? b = index[e.to];
    assert(a != null && b != null, 'KkSequenceMessage "${e.label}" names a participant that is not in the diagram.');
    final TextStyle small = type.mono(10 * _k, color: colors.inkFaint);
    if (diagram.numbered) {
      kkPaintText(
        canvas,
        (number + 1).toString().padLeft(2, '0'),
        small,
        Offset(layout.padding.left, y),
        align: Alignment.centerLeft,
      );
    }
    final double t = _wipe(number);
    if (a == null || b == null || t <= 0) return;

    // Stop at the edge of an activation bar rather than inside it.
    double inset(int column) {
      int depth = 0;
      for (final ({int column, int from, int to, int depth}) bar in bars) {
        if (bar.column == column && row >= bar.from && row <= bar.to) depth = math.max(depth, bar.depth + 1);
      }
      return depth == 0 ? 0 : 4.0 + (depth - 1) * 4;
    }

    final bool reply = e.kind == KkSequenceMessageKind.reply;
    final Color color = e.level != null ? colors.level(e.level) : (reply ? colors.inkDim : colors.signal);
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.miter
      ..color = color;
    final TextStyle labelStyle = type.mono(10 * _k, weight: FontWeight.w500, color: e.level == KkLevel.critical ? colors.alert : colors.ink);

    List<Offset> points;
    Offset labelAt;
    Alignment labelAlign;
    if (a == b) {
      final double x = layout.xs[a] + inset(a);
      points = <Offset>[Offset(x, y), Offset(x + 28, y), Offset(x + 28, y + 16), Offset(x, y + 16)];
      labelAt = Offset(x + 36, y + 8);
      labelAlign = Alignment.centerLeft;
    } else {
      final bool right = layout.xs[b] > layout.xs[a];
      final double from = layout.xs[a] + (right ? inset(a) : -math.min(inset(a), 4));
      final double to = layout.xs[b] + (right ? -math.min(inset(b), 4) : inset(b));
      points = <Offset>[Offset(from, y), Offset(to, y)];
      labelAt = Offset((from + to) / 2, y - 5);
      labelAlign = Alignment.bottomCenter;
    }
    double length = 0;
    for (int i = 1; i < points.length; i++) {
      length += (points[i] - points[i - 1]).distance;
    }
    final List<Offset> shown = t >= 1 ? points : _trim(points, length * t);
    if (shown.length >= 2) {
      Path path = Path()..addPolygon(shown, false);
      if (reply) path = kkDashPath(path, const <double>[4, 3]);
      canvas.drawPath(path, line);
    }
    kkPaintText(canvas, e.label, labelStyle, labelAt, align: labelAlign);
    final String? note = e.note;
    if (note != null && note.isNotEmpty) {
      kkPaintText(
        canvas,
        note,
        type.mono(10 * _k, color: colors.inkDim),
        Offset(layout.size.width - layout.padding.right, y),
        align: Alignment.centerRight,
      );
    }
    if (t < 1) return;
    final Offset tip = points.last;
    final Offset prev = points[points.length - 2];
    final Offset d = (tip - prev) / (tip - prev).distance;
    final Offset n = Offset(-d.dy, d.dx);
    const double s = 5;
    final Path head = Path()
      ..moveTo(tip.dx - (d.dx + n.dx) * s, tip.dy - (d.dy + n.dy) * s)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - (d.dx - n.dx) * s, tip.dy - (d.dy - n.dy) * s);
    if (e.kind == KkSequenceMessageKind.call) {
      canvas.drawPath(head..close(), Paint()..color = color);
    } else {
      canvas.drawPath(head, line);
    }
  }

  static List<Offset> _trim(List<Offset> points, double distance) {
    final List<Offset> out = <Offset>[points.first];
    double left = distance;
    for (int i = 1; i < points.length; i++) {
      final double seg = (points[i] - points[i - 1]).distance;
      if (left >= seg) {
        out.add(points[i]);
        left -= seg;
      } else {
        if (seg > 0 && left > 0) out.add(Offset.lerp(points[i - 1], points[i], left / seg)!);
        break;
      }
    }
    return out;
  }

}

class _ArrowSwatch extends StatelessWidget {
  const _ArrowSwatch(this.kind);

  final KkSequenceMessageKind kind;

  @override
  Widget build(BuildContext context) {
    final KkColors c = KeikaiTheme.of(context).colors;
    return ExcludeSemantics(
      child: CustomPaint(size: const Size(24, 10), painter: _ArrowSwatchPainter(kind, c)),
    );
  }
}

class _ArrowSwatchPainter extends CustomPainter {
  _ArrowSwatchPainter(this.kind, this.colors);

  final KkSequenceMessageKind kind;
  final KkColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final double y = size.height / 2;
    final bool reply = kind == KkSequenceMessageKind.reply;
    final Color color = reply ? colors.inkDim : colors.signal;
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.miter
      ..color = color;
    final Path wire = Path()
      ..moveTo(0, y)
      ..lineTo(size.width - 1, y);
    canvas.drawPath(reply ? kkDashPath(wire, const <double>[4, 3]) : wire, line);
    final double tip = size.width - 1;
    final Path head = Path()
      ..moveTo(tip - 4, y - 4)
      ..lineTo(tip, y)
      ..lineTo(tip - 4, y + 4);
    if (kind == KkSequenceMessageKind.call) {
      canvas.drawPath(head..close(), Paint()..color = color);
    } else {
      canvas.drawPath(head, line);
    }
  }

  @override
  bool shouldRepaint(_ArrowSwatchPainter old) => old.kind != kind || old.colors != colors;
}

/// The width [diagram] needs to show its participants and messages at full
/// size, without a frame. Give it to a horizontal scroll view as the content
/// width when the diagram must not shrink.
double kkSequenceNaturalWidth(KkSequenceDiagram diagram, {double typeScale = 1}) =>
    _SequenceLayout.natural(diagram, typeScale).size.width;
