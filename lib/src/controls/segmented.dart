import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';
import 'control_style.dart';

/// One segment of a [KkSegmented].
@immutable
class KkSegment<T> {
  const KkSegment({required this.value, this.label, this.cjk, this.enabled = true, this.semanticLabel})
    : assert(label != null || cjk != null, 'A segment needs a label or a cjk word.');

  final T value;

  /// Latin text; it is upper-cased.
  final String? label;

  /// A 漢字 or Hangul word shown before [label].
  final String? cjk;
  final bool enabled;

  /// Replaces the visible text for screen readers.
  final String? semanticLabel;
}

/// A row of joined segments: pick one (the default) or several
/// ([KkSegmented.multi]).
///
/// Every segment carries a lamp, a small square that fills when the segment
/// is on. The lamp's place is always reserved, so selecting never moves the
/// text. Arrow keys move between segments; in single mode the selection
/// follows the focus, as in a radio group.
class KkSegmented<T> extends StatefulWidget {
  /// Exactly one segment is on.
  const KkSegmented({
    super.key,
    required this.segments,
    required this.value,
    this.onChanged,
    this.lamp = true,
    this.enabled = true,
    this.expand = false,
  }) : multi = false,
       values = null,
       onValuesChanged = null;

  /// Any number of segments are on; each press toggles one.
  const KkSegmented.multi({
    super.key,
    required this.segments,
    required Set<T> this.values,
    this.onValuesChanged,
    this.lamp = true,
    this.enabled = true,
    this.expand = false,
  }) : multi = true,
       value = null,
       onChanged = null;

  final List<KkSegment<T>> segments;

  /// The selected value in single mode. Null selects nothing.
  final T? value;

  /// Called with the newly selected value. Null disables the control.
  final ValueChanged<T>? onChanged;

  /// The selected values in multi mode.
  final Set<T>? values;

  /// Called with the new set after a segment is toggled. Null disables the control.
  final ValueChanged<Set<T>>? onValuesChanged;
  final bool multi;

  /// Show the lamp in every segment.
  final bool lamp;
  final bool enabled;

  /// Share the available width equally between the segments.
  final bool expand;

  @override
  State<KkSegmented<T>> createState() => _KkSegmentedState<T>();
}

class _KkSegmentedState<T> extends State<KkSegmented<T>> {
  final List<FocusNode> _nodes = <FocusNode>[];
  final List<GlobalKey> _keys = <GlobalKey>[];
  int? _ring;

  @override
  void initState() {
    super.initState();
    _syncNodes();
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
  }

  @override
  void didUpdateWidget(KkSegmented<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncNodes();
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    for (final FocusNode node in _nodes) {
      node
        ..removeListener(_updateRing)
        ..dispose();
    }
    super.dispose();
  }

  void _syncNodes() {
    final int n = widget.segments.length;
    while (_nodes.length < n) {
      _nodes.add(FocusNode(debugLabel: 'KkSegment')..addListener(_updateRing));
      _keys.add(GlobalKey());
    }
    while (_nodes.length > n) {
      _nodes.removeLast()
        ..removeListener(_updateRing)
        ..dispose();
      _keys.removeLast();
    }
  }

  void _onHighlightMode(FocusHighlightMode mode) => _updateRing();

  void _updateRing() {
    if (!mounted) return;
    int? index;
    if (FocusManager.instance.highlightMode == FocusHighlightMode.traditional) {
      for (int i = 0; i < _nodes.length; i++) {
        if (_nodes[i].hasPrimaryFocus) index = i;
      }
    }
    if (index != _ring) setState(() => _ring = index);
  }

  bool get _hasCallback => widget.multi ? widget.onValuesChanged != null : widget.onChanged != null;

  bool _isOn(int i) {
    final T v = widget.segments[i].value;
    return widget.multi ? (widget.values?.contains(v) ?? false) : widget.value == v;
  }

  bool _isLive(int i) => widget.enabled && _hasCallback && widget.segments[i].enabled;

  void _activate(int i) {
    if (!_isLive(i)) return;
    final T v = widget.segments[i].value;
    if (widget.multi) {
      final Set<T> next = Set<T>.of(widget.values ?? <T>{});
      if (!next.remove(v)) next.add(v);
      widget.onValuesChanged?.call(next);
    } else if (widget.value != v) {
      widget.onChanged?.call(v);
    }
  }

  int? _step(int from, int direction) {
    final int n = widget.segments.length;
    for (int k = 1; k <= n; k++) {
      final int i = ((from + direction * k) % n + n) % n;
      if (_isLive(i)) return i;
    }
    return null;
  }

  int? _edge({required bool last}) {
    final int n = widget.segments.length;
    for (int k = 0; k < n; k++) {
      final int i = last ? n - 1 - k : k;
      if (_isLive(i)) return i;
    }
    return null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final int current = _nodes.indexWhere((FocusNode n) => n.hasPrimaryFocus);
    if (current < 0) return KeyEventResult.ignored;
    final LogicalKeyboardKey key = event.logicalKey;
    int? target;
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowDown) {
      target = _step(current, 1);
    } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowUp) {
      target = _step(current, -1);
    } else if (key == LogicalKeyboardKey.home) {
      target = _edge(last: false);
    } else if (key == LogicalKeyboardKey.end) {
      target = _edge(last: true);
    } else {
      return KeyEventResult.ignored;
    }
    if (target != null && target != current) {
      _nodes[target].requestFocus();
      if (!widget.multi) _activate(target);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final int n = widget.segments.length;
    final List<bool> on = <bool>[for (int i = 0; i < n; i++) _isOn(i)];

    // Single mode keeps one tab stop, like a radio group: the selected
    // segment, or the first live one when nothing is selected.
    int? tabStop;
    if (!widget.multi) {
      for (int i = 0; i < n && tabStop == null; i++) {
        if (on[i] && _isLive(i)) tabStop = i;
      }
      tabStop ??= _edge(last: false);
    }

    int? ring = _ring;
    final KkStateOverride? forced = context.dependOnInheritedWidgetOfExactType<KkStateOverride>();
    if (ring == null && (forced?.focused ?? false)) ring = tabStop ?? _edge(last: false);
    if (ring != null && ring >= n) ring = null;

    final List<Widget> children = <Widget>[
      for (int i = 0; i < n; i++) _segment(context, i, on[i], tabStop, c, m),
    ];
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: KkBox(
        decoration: KkDecoration(
          fill: c.bg100,
          edges: KkEdges.line(c.inkFaint, width: m.stroke1),
        ),
        child: _SegmentOverlay(
          keys: List<GlobalKey>.of(_keys),
          on: on,
          ring: ring,
          line: c.line,
          gap: c.bg000,
          focus: c.focus,
          stroke: m.stroke1,
          ringWidth: m.stroke2,
          child: KkRow(shrinkWrap: !widget.expand, cross: KkCrossAlign.stretch, children: children),
        ),
      ),
    );
  }

  Widget _segment(BuildContext context, int i, bool on, int? tabStop, KkColors c, KkMetrics m) {
    final KkSegment<T> seg = widget.segments[i];
    final bool live = _isLive(i);
    _nodes[i].skipTraversal = tabStop != null && tabStop != i;
    Widget child = KkPressable(
      focusNode: _nodes[i],
      enabled: live,
      onPressed: () => _activate(i),
      button: widget.multi,
      toggled: widget.multi ? on : null,
      checked: widget.multi ? null : on,
      semanticLabel: seg.semanticLabel,
      excludeSemantics: seg.semanticLabel != null,
      builder: (BuildContext context, KkStates raw) {
        final KkStates s = KkStateOverride.resolve(context, raw);
        final Color? fill;
        final Color ink;
        if (!live) {
          fill = null;
          ink = c.inkFaint;
        } else if (on) {
          fill = c.signal;
          ink = c.onFill;
        } else if (s.hovered) {
          fill = c.bg300;
          ink = c.ink;
        } else {
          fill = null;
          ink = c.inkDim;
        }
        final String? cjk = seg.cjk;
        final String? label = seg.label;
        return KkBox(
          key: _keys[i],
          height: 30,
          padding: EdgeInsets.only(left: 10, right: m.space3),
          alignment: widget.expand ? Alignment.center : null,
          fill: fill,
          child: KkRow(
            shrinkWrap: true,
            gap: 7,
            clip: Clip.hardEdge,
            children: <Widget>[
              if (widget.lamp)
                KkBox(
                  width: 12,
                  height: 12,
                  alignment: Alignment.center,
                  child: KkBox(
                    width: 8,
                    height: 8,
                    decoration: KkDecoration(fill: on ? ink : null, edges: KkEdges.line(ink, width: 1.5)),
                  ),
                ),
              if (cjk != null && cjk.isNotEmpty) KkText.cjk(cjk, size: 14, color: ink, squeeze: 0.8),
              if (label != null && label.isNotEmpty) KkText.en(label, size: 13, spacing: 0.1, color: ink),
            ],
          ),
        );
      },
    );
    if (!widget.multi) {
      child = MergeSemantics(
        child: Semantics(inMutuallyExclusiveGroup: true, child: child),
      );
    }
    return widget.expand ? KkExpanded(child: child) : child;
  }
}

/// Draws what sits between and over the segments: the hairline between two
/// idle neighbours, the black cut between two lit ones, and the keyboard
/// focus ring (which must not be covered by the next segment's fill).
class _SegmentOverlay extends SingleChildRenderObjectWidget {
  const _SegmentOverlay({
    required this.keys,
    required this.on,
    required this.ring,
    required this.line,
    required this.gap,
    required this.focus,
    required this.stroke,
    required this.ringWidth,
    super.child,
  });

  final List<GlobalKey> keys;
  final List<bool> on;
  final int? ring;
  final Color line;
  final Color gap;
  final Color focus;
  final double stroke;
  final double ringWidth;

  @override
  _RenderSegmentOverlay createRenderObject(BuildContext context) => _RenderSegmentOverlay()
    ..keys = keys
    ..on = on
    ..ring = ring
    ..line = line
    ..gap = gap
    ..focus = focus
    ..stroke = stroke
    ..ringWidth = ringWidth;

  @override
  void updateRenderObject(BuildContext context, _RenderSegmentOverlay renderObject) {
    final bool changed =
        !listEquals(renderObject.keys, keys) ||
        !listEquals(renderObject.on, on) ||
        renderObject.ring != ring ||
        renderObject.line != line ||
        renderObject.gap != gap ||
        renderObject.focus != focus ||
        renderObject.stroke != stroke ||
        renderObject.ringWidth != ringWidth;
    renderObject
      ..keys = keys
      ..on = on
      ..ring = ring
      ..line = line
      ..gap = gap
      ..focus = focus
      ..stroke = stroke
      ..ringWidth = ringWidth;
    if (changed) renderObject.markNeedsPaint();
  }
}

class _RenderSegmentOverlay extends RenderProxyBox {
  List<GlobalKey> keys = const <GlobalKey>[];
  List<bool> on = const <bool>[];
  int? ring;
  Color line = const Color(0x00000000);
  Color gap = const Color(0x00000000);
  Color focus = const Color(0x00000000);
  double stroke = 1;
  double ringWidth = 2;

  Rect? _rectOf(int i, Offset offset) {
    if (i < 0 || i >= keys.length) return null;
    final RenderObject? ro = keys[i].currentContext?.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    return (offset + ro.localToGlobal(Offset.zero, ancestor: this)) & ro.size;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final Canvas canvas = context.canvas;
    final Paint paint = Paint();
    for (int i = 1; i < keys.length && i < on.length; i++) {
      final Rect? r = _rectOf(i, offset);
      if (r == null) continue;
      if (on[i - 1] && on[i]) {
        canvas.drawRect(Rect.fromLTWH(r.left - stroke, r.top, stroke * 2, r.height), paint..color = gap);
      } else if (!on[i - 1] && !on[i] && r.height > 14) {
        canvas.drawRect(Rect.fromLTWH(r.left, r.top + 7, stroke, r.height - 14), paint..color = line);
      }
    }
    final int? index = ring;
    if (index != null) {
      final Rect? r = _rectOf(index, offset);
      if (r != null) {
        canvas.drawRect(
          r.inflate(2 + ringWidth / 2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = ringWidth
            ..color = focus,
        );
      }
    }
  }
}
