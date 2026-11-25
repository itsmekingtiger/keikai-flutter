import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/flex.dart';
import '../layout/wrap.dart';
import '../painting/shapes.dart';
import '../widgets/pressable.dart';
import 'control_style.dart';
import 'option_label.dart';

/// One choice of a [KkRadioGroup].
@immutable
class KkRadioOption<T> {
  const KkRadioOption({required this.value, this.label, this.cjk, this.enabled = true, this.semanticLabel});

  final T value;

  /// Latin text; it is upper-cased.
  final String? label;

  /// A 漢字 or Hangul word shown before [label].
  final String? cjk;
  final bool enabled;

  /// Replaces the visible label for screen readers.
  final String? semanticLabel;
}

/// A group of options of which exactly one is chosen. The mark is a hexagon
/// with a signal core.
///
/// The group is one tab stop; arrow keys move the choice between live
/// options and wrap at the ends.
class KkRadioGroup<T> extends StatefulWidget {
  const KkRadioGroup({
    super.key,
    required this.options,
    required this.value,
    this.onChanged,
    this.direction = Axis.vertical,
    this.enabled = true,
    this.semanticLabel,
  });

  final List<KkRadioOption<T>> options;

  /// The chosen value. Null chooses nothing.
  final T? value;

  /// Called with the newly chosen value. Null disables the group.
  final ValueChanged<T>? onChanged;

  /// Vertical stacks the options 8px apart; horizontal lays them in a row
  /// (16px apart) that wraps.
  final Axis direction;
  final bool enabled;

  /// Names the group for screen readers.
  final String? semanticLabel;

  @override
  State<KkRadioGroup<T>> createState() => _KkRadioGroupState<T>();
}

class _KkRadioGroupState<T> extends State<KkRadioGroup<T>> {
  final List<FocusNode> _nodes = <FocusNode>[];

  @override
  void initState() {
    super.initState();
    _syncNodes();
  }

  @override
  void didUpdateWidget(KkRadioGroup<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncNodes();
  }

  @override
  void dispose() {
    for (final FocusNode node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _syncNodes() {
    final int n = widget.options.length;
    while (_nodes.length < n) {
      _nodes.add(FocusNode(debugLabel: 'KkRadioOption'));
    }
    while (_nodes.length > n) {
      _nodes.removeLast().dispose();
    }
  }

  bool _isLive(int i) => widget.enabled && widget.onChanged != null && widget.options[i].enabled;

  void _choose(int i) {
    if (!_isLive(i)) return;
    final T v = widget.options[i].value;
    if (v != widget.value) widget.onChanged?.call(v);
  }

  int? _step(int from, int direction) {
    final int n = widget.options.length;
    for (int k = 1; k <= n; k++) {
      final int i = ((from + direction * k) % n + n) % n;
      if (_isLive(i)) return i;
    }
    return null;
  }

  int? _first() {
    for (int i = 0; i < widget.options.length; i++) {
      if (_isLive(i)) return i;
    }
    return null;
  }

  int? _last() {
    for (int i = widget.options.length - 1; i >= 0; i--) {
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
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowRight) {
      target = _step(current, 1);
    } else if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowLeft) {
      target = _step(current, -1);
    } else if (key == LogicalKeyboardKey.home) {
      target = _first();
    } else if (key == LogicalKeyboardKey.end) {
      target = _last();
    } else {
      return KeyEventResult.ignored;
    }
    if (target != null && target != current) {
      _nodes[target].requestFocus();
      _choose(target);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final int n = widget.options.length;

    int? tabStop;
    for (int i = 0; i < n && tabStop == null; i++) {
      if (widget.options[i].value == widget.value && widget.value != null && _isLive(i)) tabStop = i;
    }
    tabStop ??= _first();

    final List<Widget> children = <Widget>[for (int i = 0; i < n; i++) _option(i, tabStop, c, m)];
    final Widget layout = widget.direction == Axis.vertical
        ? KkColumn(shrinkWrap: true, gap: m.space2, cross: KkCrossAlign.start, children: children)
        : KkWrap(gap: m.space4, runGap: m.space2, children: children);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: Semantics(container: true, explicitChildNodes: true, label: widget.semanticLabel, child: layout),
    );
  }

  Widget _option(int i, int? tabStop, KkColors c, KkMetrics m) {
    final KkRadioOption<T> option = widget.options[i];
    final bool live = _isLive(i);
    final bool chosen = widget.value != null && option.value == widget.value;
    final bool hasLabel = (option.label?.isNotEmpty ?? false) || (option.cjk?.isNotEmpty ?? false);
    _nodes[i].skipTraversal = tabStop != null && tabStop != i;
    return MergeSemantics(
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        child: KkPressable(
          focusNode: _nodes[i],
          enabled: live,
          onPressed: () => _choose(i),
          button: false,
          checked: chosen,
          semanticLabel: option.semanticLabel,
          excludeSemantics: option.semanticLabel != null,
          builder: (BuildContext context, KkStates raw) {
            final KkStates s = KkStateOverride.resolve(context, raw);
            final Color edge = !live ? c.offline : ((chosen || s.hovered) ? c.signal : c.inkFaint);
            return KkRow(
              shrinkWrap: true,
              gap: m.space2,
              clip: Clip.hardEdge,
              children: <Widget>[
                KkFocusRing(
                  visible: s.focused,
                  offset: 2,
                  width: m.stroke2,
                  child: CustomPaint(
                    size: const Size.square(16),
                    painter: _RadioPainter(edge: edge, fill: c.bg100, core: chosen ? c.signal : null),
                  ),
                ),
                if (hasLabel)
                  KkFlexible(
                    child: KkOptionLabel(label: option.label, cjk: option.cjk, color: live ? c.ink : c.inkFaint),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The hexagon mark: a pointy-top outline (1.5px, the icon set's line) and,
/// when chosen, a filled hexagon core.
class _RadioPainter extends CustomPainter {
  const _RadioPainter({required this.edge, required this.fill, required this.core});

  final Color edge;
  final Color fill;
  final Color? core;

  @override
  void paint(Canvas canvas, Size size) {
    final double k = size.shortestSide / 16;
    final Offset centre = size.center(Offset.zero);
    final Path outline = kkPolygon(centre, 7 * k, 6);
    canvas.drawPath(outline, Paint()..color = fill);
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * k
        ..strokeJoin = StrokeJoin.miter
        ..color = edge,
    );
    final Color? dot = core;
    if (dot != null) canvas.drawPath(kkPolygon(centre, 3.5 * k, 6), Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_RadioPainter oldDelegate) =>
      oldDelegate.edge != edge || oldDelegate.fill != fill || oldDelegate.core != core;
}
