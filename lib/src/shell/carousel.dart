import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../controls/control_style.dart';
import '../controls/icon_button.dart';
import '../foundation/colors.dart';
import '../foundation/icons.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../foundation/tokens.dart';
import '../layout/box.dart';
import '../layout/flex.dart';
import '../layout/layers.dart';
import '../painting/decoration.dart';
import '../painting/shapes.dart';
import '../widgets/pressable.dart';
import '../widgets/text.dart';

/// One card of a [KkCarousel].
@immutable
class KkCarouselItem {
  const KkCarouselItem({required this.child, this.caption, this.onPressed, this.semanticLabel});

  /// The content; it fills the card and is clipped to it.
  final Widget child;

  /// A small mono plate at the bottom left of the card: `CAM-03 · SEC-04`.
  final String? caption;

  /// Makes the card a button.
  final VoidCallback? onPressed;

  /// Replaces the caption for screen readers.
  final String? semanticLabel;
}

/// A row of same-sized cards that scrolls sideways and always comes to rest
/// with a card at the left edge.
///
/// The head shows the title, a count such as `03 / 08` and previous / next
/// buttons. Left and Right move by one card while the carousel (or a card in
/// it) has keyboard focus. Programmatic moves jump in 7 hard steps.
///
/// The count follows the card at the left edge; once the row is scrolled to
/// its end it reads the last card.
///
/// Pass [index] and [onChanged] to control it, or leave [index] null and it
/// keeps its own position starting at [initialIndex].
class KkCarousel extends StatefulWidget {
  const KkCarousel({
    super.key,
    this.cjk,
    this.en,
    required this.items,
    this.index,
    this.initialIndex = 0,
    this.onChanged,
    this.itemWidth = 240,
    this.itemHeight = 152,
    this.gap,
    this.showHead = true,
    this.showControls = true,
    this.previousLabel = 'Previous',
    this.nextLabel = 'Next',
  }) : assert(itemWidth > 0),
       assert(itemHeight > 0);

  final String? cjk;

  /// Upper-cased.
  final String? en;
  final List<KkCarouselItem> items;

  /// The card at the left edge (controlled). Null lets the carousel keep its
  /// own position.
  final int? index;

  /// Where an uncontrolled carousel starts.
  final int initialIndex;

  /// Called when the leading card changes, by button, key or scrolling.
  final ValueChanged<int>? onChanged;
  final double itemWidth;
  final double itemHeight;

  /// Space between cards. Defaults to 8.
  final double? gap;

  /// Show the head row (title, count, buttons).
  final bool showHead;

  /// Show the previous / next buttons in the head.
  final bool showControls;

  /// What screen readers call the two buttons.
  final String previousLabel;
  final String nextLabel;

  @override
  State<KkCarousel> createState() => _KkCarouselState();
}

class _KkCarouselState extends State<KkCarousel> {
  late final ScrollController _controller;
  late int _own = widget.initialIndex;
  bool _programmatic = false;
  bool _focused = false;

  int get _count => widget.items.length;
  double get _gap => widget.gap ?? 8;
  double get _extent => widget.itemWidth + _gap;
  int get _index => _count == 0 ? 0 : (widget.index ?? _own).clamp(0, _count - 1);

  @override
  void initState() {
    super.initState();
    _controller = ScrollController(initialScrollOffset: math.max(0, _index * _extent));
  }

  @override
  void didUpdateWidget(KkCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int? now = widget.index;
    if (now != null && now != oldWidget.index) {
      // Follow the controlled index once this frame is laid out.
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (mounted) _scrollTo(_index);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _targetFor(int i) {
    final double raw = i * _extent;
    if (!_controller.hasClients) return raw;
    return raw.clamp(0.0, _controller.position.maxScrollExtent);
  }

  bool get _atEnd {
    if (!_controller.hasClients) return false;
    final ScrollPosition p = _controller.position;
    return p.maxScrollExtent > 0 && p.pixels >= p.maxScrollExtent - 0.5;
  }

  void _scrollTo(int i) {
    if (!_controller.hasClients) return;
    final double target = _targetFor(i);
    if ((target - _controller.position.pixels).abs() < 0.5) return;
    _programmatic = true;
    if (KeikaiTheme.motionOf(context)) {
      _controller
          .animateTo(
            target,
            duration: KeikaiTheme.of(context).motion.scaled(KkMotion.boot),
            curve: const KkSteps(KkMotion.bootSteps),
          )
          .whenComplete(() => _programmatic = false);
    } else {
      _controller.jumpTo(target);
      _programmatic = false;
    }
  }

  void _report(int i) {
    if (i == _index) return;
    if (widget.index == null) setState(() => _own = i);
    widget.onChanged?.call(i);
  }

  /// Goes to card [i]. A card that can only be reached by scrolling to the
  /// very end counts as the last one.
  void _select(int i) {
    if (_count == 0) return;
    int to = i.clamp(0, _count - 1);
    if (_controller.hasClients) {
      final double max = _controller.position.maxScrollExtent;
      if (max > 0 && to * _extent >= max - 0.5) to = _count - 1;
    }
    _report(to);
    _scrollTo(to);
  }

  void _next() => _select(_index + 1);

  void _previous() {
    int to = _index - 1;
    if (_controller.hasClients) {
      // Skip the cards that would not move the row (they all sit at the end).
      final double here = _controller.position.pixels;
      while (to > 0 && (_targetFor(to) - here).abs() < 0.5) {
        to--;
      }
    }
    _select(math.max(0, to));
  }

  bool _onScrollEnd(ScrollEndNotification notification) {
    if (_programmatic || notification.depth != 0 || !_controller.hasClients || _count == 0) return false;
    final double pixels = _controller.position.pixels;
    int i = (pixels / _extent).round().clamp(0, _count - 1);
    if (_atEnd) i = _count - 1;
    _report(i);
    return false;
  }

  static String _two(int v) => v < 10 ? '0$v' : '$v';

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final String? cjk = widget.cjk;
    final String? en = widget.en;
    final int index = _index;
    final bool canPrevious = _count > 0 && index > 0;
    final bool canNext = _count > 0 && index < _count - 1;

    final Widget track = FocusableActionDetector(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowLeft): _CarouselIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowRight): _CarouselIntent(1),
      },
      actions: <Type, Action<Intent>>{
        _CarouselIntent: CallbackAction<_CarouselIntent>(
          onInvoke: (_CarouselIntent intent) {
            if (intent.delta < 0) {
              _previous();
            } else {
              _next();
            }
            return null;
          },
        ),
      },
      onShowFocusHighlight: (bool value) {
        if (value != _focused) setState(() => _focused = value);
      },
      child: KkFocusRing(
        visible: _focused,
        offset: 2,
        width: m.stroke2,
        child: NotificationListener<ScrollEndNotification>(
          onNotification: _onScrollEnd,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _controller,
            physics: _KkSnapPhysics(extent: _extent),
            child: KkBox(
              // Room for the scrollbar thumb under the cards.
              padding: EdgeInsets.only(bottom: m.space2),
              child: KkRow(
                shrinkWrap: true,
                cross: KkCrossAlign.start,
                gap: _gap,
                children: <Widget>[
                  for (int i = 0; i < _count; i++)
                    _KkCarouselCard(item: widget.items[i], width: widget.itemWidth, height: widget.itemHeight),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!widget.showHead) return track;

    return KkColumn(
      shrinkWrap: true,
      gap: m.space2,
      children: <Widget>[
        KkRow(
          gap: m.space2,
          clip: Clip.hardEdge,
          children: <Widget>[
            if (cjk != null) KkText.cjk(cjk, size: 14, color: c.ink, squeeze: 0.8),
            if (en != null) KkText.en(en, size: 11, weight: FontWeight.w600, spacing: 0.14, color: c.inkDim),
            const KkSpacer(),
            Semantics(
              container: true,
              label: 'Item ${_count == 0 ? 0 : index + 1} of $_count',
              child: ExcludeSemantics(
                child: KkBox(
                  padding: EdgeInsets.only(right: m.space1),
                  child: KkText.num(
                    '${_two(_count == 0 ? 0 : index + 1)} / ${_two(_count)}',
                    size: 12,
                    weight: FontWeight.w500,
                    color: c.ink,
                  ),
                ),
              ),
            ),
            if (widget.showControls) ...<Widget>[
              KkIconButton(
                icon: KkIcons.chevronLeft,
                variant: KkIconButtonVariant.outline,
                size: KkIconButtonSize.sm,
                semanticLabel: widget.previousLabel,
                onPressed: canPrevious ? _previous : null,
              ),
              KkIconButton(
                icon: KkIcons.chevronRight,
                variant: KkIconButtonVariant.outline,
                size: KkIconButtonSize.sm,
                semanticLabel: widget.nextLabel,
                onPressed: canNext ? _next : null,
              ),
            ],
          ],
        ),
        track,
      ],
    );
  }
}

class _CarouselIntent extends Intent {
  const _CarouselIntent(this.delta);

  final int delta;
}

class _KkCarouselCard extends StatelessWidget {
  const _KkCarouselCard({required this.item, required this.width, required this.height});

  final KkCarouselItem item;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final String? caption = item.caption;

    Widget card(KkStates s) => KkFocusRing(
      visible: s.focused,
      offset: -m.stroke2,
      width: m.stroke2,
      child: KkBox(
        width: width,
        height: height,
        decoration: KkDecoration(
          fill: c.bg100,
          edges: KkEdges.line(s.hovered ? c.signal : c.line, width: m.stroke1),
        ),
        clip: true,
        child: KkLayers(
          expand: true,
          children: <Widget>[
            item.child,
            if (caption != null)
              KkPositioned(
                left: m.space2,
                bottom: m.space2,
                child: KkBox(
                  fill: c.bg000,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: KkText.num(caption, size: 11, weight: FontWeight.w500, color: c.ink),
                ),
              ),
          ],
        ),
      ),
    );

    if (item.onPressed == null) {
      return Semantics(
        container: true,
        label: item.semanticLabel,
        child: card(const KkStates()),
      );
    }
    return KkPressable(
      onPressed: item.onPressed,
      semanticLabel: item.semanticLabel ?? caption,
      builder: (BuildContext context, KkStates raw) => card(KkStateOverride.resolve(context, raw)),
    );
  }
}

/// Scroll physics that settle on multiples of [extent]: the row always rests
/// with a card at its leading edge (or at the very end).
class _KkSnapPhysics extends ScrollPhysics {
  const _KkSnapPhysics({required this.extent, super.parent});

  final double extent;

  @override
  _KkSnapPhysics applyTo(ScrollPhysics? ancestor) => _KkSnapPhysics(extent: extent, parent: buildParent(ancestor));

  double _target(ScrollMetrics position, Tolerance tolerance, double velocity) {
    double item = position.pixels / extent;
    if (velocity < -tolerance.velocity) {
      item -= 0.5;
    } else if (velocity > tolerance.velocity) {
      item += 0.5;
    }
    return (item.roundToDouble() * extent).clamp(position.minScrollExtent, position.maxScrollExtent);
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // Out of range: let the parent physics bring it back.
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final Tolerance tolerance = toleranceFor(position);
    final double target = _target(position, tolerance, velocity);
    if ((target - position.pixels).abs() < tolerance.distance) return null;
    return ScrollSpringSimulation(spring, position.pixels, target, velocity, tolerance: tolerance);
  }

  @override
  bool get allowImplicitScrolling => false;
}
