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

  /// What screen readers call the card, instead of reading the caption.
  final String? semanticLabel;
}

/// A row of same-sized cards that scrolls sideways and always comes to rest
/// with a card at the left edge.
///
/// The head shows the title, a count such as `03 / 08` and previous / next
/// buttons. Programmatic moves jump in 7 hard steps. A drag or fling settles
/// on the card nearest to where it would have stopped.
///
/// Keyboard: the row is a tab stop and Left and Right move it by one card.
/// When cards are buttons they are the tab stops instead, in card order;
/// the arrow keys then go from card to card, and the row follows so that the
/// focused card is always fully in view.
///
/// The count follows the card at the left edge; once the row is scrolled to
/// its end it reads the last card. When every card fits the buttons are
/// disabled.
///
/// Pass [index] and [onChanged] to control it: the row then shows what
/// [index] says and returns to it when a move is not taken up. Leave [index]
/// null and it keeps its own position starting at [initialIndex].
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
       assert(itemHeight > 0),
       assert(gap == null || gap >= 0);

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

  /// Space between cards. Defaults to the theme's space-2 (8).
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
  ScrollController? _scroll;
  final FocusNode _trackNode = FocusNode(debugLabel: 'KkCarousel');
  late int _own = widget.initialIndex;
  double _themeGap = 8;

  final OrderedTraversalPolicy _order = OrderedTraversalPolicy();

  /// Programmatic moves so far. A scroll that ends while the latest one is
  /// in flight is not the user's doing.
  int _moves = 0;
  bool _programmatic = false;
  bool _starting = false;
  double? _movingTo;
  bool _highlight = false;
  bool _trackFocused = false;

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{_CarouselIntent: _KkCarouselStep(this)};

  ScrollController get _controller => _scroll!;
  int get _count => widget.items.length;
  double get _gap => widget.gap ?? _themeGap;
  double get _extent => widget.itemWidth + _gap;
  int get _index => _count == 0 ? 0 : (widget.index ?? _own).clamp(0, _count - 1);
  bool get _laidOut => _controller.hasClients && _controller.position.hasContentDimensions;

  /// Read by the scroll physics, which outlive a change of card size.
  double _extentNow() => _extent;

  @override
  void initState() {
    super.initState();
    _trackNode.addListener(_onTrackFocus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final double gap = KeikaiTheme.of(context).metrics.space2;
    final bool moved = _scroll != null && widget.gap == null && gap != _themeGap;
    _themeGap = gap;
    _scroll ??= ScrollController(initialScrollOffset: math.max(0.0, _index * _extent));
    if (moved) _afterLayout(() => _scrollTo(_index, animate: false));
  }

  @override
  void didUpdateWidget(KkCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int? now = widget.index;
    if (oldWidget.itemWidth != widget.itemWidth || oldWidget.gap != widget.gap) {
      // The cards changed size: keep the same card at the leading edge.
      _afterLayout(() => _scrollTo(_index, animate: false));
    } else if (now != null && now != oldWidget.index) {
      // Follow the controlled index once this frame is laid out.
      _afterLayout(() => _scrollTo(_index));
    }
  }

  @override
  void dispose() {
    _trackNode
      ..removeListener(_onTrackFocus)
      ..dispose();
    _scroll?.dispose();
    super.dispose();
  }

  void _afterLayout(VoidCallback move) {
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) move();
    });
  }

  void _onTrackFocus() {
    final bool now = _trackNode.hasPrimaryFocus;
    if (now != _trackFocused && mounted) setState(() => _trackFocused = now);
  }

  /// Where the row rests with card [i] leading.
  double _targetFor(int i) {
    final double raw = i * _extent;
    if (!_laidOut) return raw;
    final ScrollPosition position = _controller.position;
    return raw.clamp(position.minScrollExtent, position.maxScrollExtent);
  }

  void _scrollTo(int i, {bool animate = true}) {
    if (!_laidOut) return;
    final ScrollPosition position = _controller.position;
    final double target = _targetFor(i);
    final bool there = (target - position.pixels).abs() < 0.5;
    // Already there and at rest, or already on the way.
    if (there && !position.isScrollingNotifier.value) return;
    if (_programmatic && _movingTo == target) return;
    final int move = ++_moves;
    _programmatic = true;
    _movingTo = target;
    void done() {
      if (_moves != move) return;
      _programmatic = false;
      _movingTo = null;
    }

    final Duration duration = KeikaiTheme.of(context).motion.scaled(KkMotion.boot);
    _starting = true;
    if (animate && !there && duration > Duration.zero && KeikaiTheme.motionOf(context)) {
      _controller.animateTo(target, duration: duration, curve: const KkSteps(KkMotion.bootSteps)).whenComplete(done);
      _starting = false;
    } else {
      _controller.jumpTo(target);
      _starting = false;
      done();
    }
  }

  void _report(int i) {
    if (i == _index) return;
    if (widget.index == null) {
      setState(() => _own = i);
    } else {
      // The owner decides: come back to its index unless it takes this one.
      _afterLayout(() => _scrollTo(_index));
      WidgetsBinding.instance.ensureVisualUpdate();
    }
    widget.onChanged?.call(i);
  }

  /// Goes to card [i]. A card that can only be shown by scrolling to the
  /// very end counts as the last one.
  void _select(int i) {
    if (_count == 0 || !_laidOut) return;
    final double max = _controller.position.maxScrollExtent;
    if (max <= 0.5) return; // Every card is in view already.
    int to = i.clamp(0, _count - 1);
    if (to * _extent >= max - 0.5) to = _count - 1;
    _report(to);
    // A controlled carousel moves when its owner passes the new index back.
    if (widget.index == null) _scrollTo(to);
  }

  void _next() => _select(_index + 1);

  void _previous() {
    if (!_laidOut) return;
    int to = _index - 1;
    // Skip the cards that rest where this one does: they all sit at the end.
    final double rest = _targetFor(_index);
    while (to > 0 && (_targetFor(to) - rest).abs() < 0.5) {
      to--;
    }
    _select(math.max(0, to));
  }

  /// Brings card [i] fully into view when it, or something in it, takes the
  /// keyboard focus.
  void _reveal(int i) {
    if (!_laidOut) return;
    final double view = _controller.position.viewportDimension;
    final double rest = _targetFor(_index);
    final double start = i * _extent;
    if (start >= rest - 0.5 && start + widget.itemWidth <= rest + view + 0.5) return;
    // Leading when it lies before the view; otherwise the first card that,
    // at the leading edge, leaves room for this one.
    _select(start < rest ? i : ((start + widget.itemWidth - view) / _extent).ceil().clamp(0, i));
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification && !_starting) {
      // A scroll that is not ours began (a wheel, the focus traversal): a
      // programmatic move still in flight has been taken over.
      _moves++;
      _programmatic = false;
      _movingTo = null;
    } else if (notification is ScrollEndNotification) {
      _onScrollEnd();
    }
    return false;
  }

  void _onScrollEnd() {
    if (_programmatic || !_laidOut || _count == 0) return;
    final ScrollPosition position = _controller.position;
    final double max = position.maxScrollExtent;
    final bool atEnd = max > 0.5 && position.pixels >= max - 0.5;
    _report(atEnd ? _count - 1 : (position.pixels / _extent).round().clamp(0, _count - 1));
  }

  static String _two(int v) => v < 10 ? '0$v' : '$v';

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: _layout);

  Widget _layout(BuildContext context, BoxConstraints constraints) {
    final KkMetrics m = KeikaiTheme.of(context).metrics;
    final int index = _index;

    // How far the row can scroll in the width it is given.
    final double content = _count == 0 ? 0 : _count * widget.itemWidth + (_count - 1) * _gap;
    final double room = constraints.hasBoundedWidth ? math.max(0.0, content - constraints.maxWidth) : 0.0;
    final bool scrolls = room > 0.5;
    // A card that can only be shown at the very end reads as the last one.
    final bool atEnd = scrolls && index * _extent >= room - 0.5;
    final int shown = _count == 0 ? 0 : (atEnd ? _count : index + 1);
    final bool canPrevious = scrolls && index > 0;
    final bool canNext = scrolls && !atEnd;

    // The row is a tab stop unless its cards are: then the focus goes from
    // card to card and the row follows it.
    final bool trackStop = !widget.items.any((KkCarouselItem item) => item.onPressed != null);

    final Widget track = FocusTraversalOrder(
      order: const NumericFocusOrder(1),
      child: FocusableActionDetector(
        enabled: trackStop,
        focusNode: _trackNode,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowLeft): _CarouselIntent(-1),
          SingleActivator(LogicalKeyboardKey.arrowRight): _CarouselIntent(1),
        },
        actions: _actions,
        onShowFocusHighlight: (bool value) {
          if (value != _highlight) setState(() => _highlight = value);
        },
        child: KkFocusRing(
          // Not while something inside has the focus: that shows its own ring.
          visible: _highlight && _trackFocused,
          offset: 2,
          width: m.stroke2,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _controller,
              physics: _KkSnapPhysics(extentOf: _extentNow),
              child: KkBox(
                // Room for the scrollbar thumb under the cards.
                padding: EdgeInsets.only(bottom: m.space2),
                child: KkRow(
                  shrinkWrap: true,
                  cross: KkCrossAlign.start,
                  gap: _gap,
                  children: <Widget>[
                    for (int i = 0; i < _count; i++)
                      // Cards keep their order whatever the scroll offset is.
                      FocusTraversalOrder(
                        order: NumericFocusOrder(2.0 + i),
                        child: Focus(
                          canRequestFocus: false,
                          skipTraversal: true,
                          includeSemantics: false,
                          onFocusChange: (bool focused) {
                            if (focused) _reveal(i);
                          },
                          child: _KkCarouselCard(
                            item: widget.items[i],
                            width: widget.itemWidth,
                            height: widget.itemHeight,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // One group, so that cards scrolled out of view do not mix with what is
    // beside the carousel: head, row, then the cards in order.
    return FocusTraversalGroup(
      policy: _order,
      child: widget.showHead ? _withHead(context, track, shown, canPrevious, canNext) : track,
    );
  }

  Widget _withHead(BuildContext context, Widget track, int shown, bool canPrevious, bool canNext) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkColors c = theme.colors;
    final KkMetrics m = theme.metrics;
    final String? cjk = widget.cjk;
    final String? en = widget.en;
    return KkColumn(
      shrinkWrap: true,
      gap: m.space2,
      children: <Widget>[
        FocusTraversalOrder(
          order: const NumericFocusOrder(0),
          child: KkRow(
            gap: m.space2,
            clip: Clip.hardEdge,
            children: <Widget>[
              if (cjk != null) KkText.cjk(cjk, size: 14, color: c.ink, squeeze: 0.8),
              if (en != null) KkText.en(en, size: 11, weight: FontWeight.w600, spacing: 0.14, color: c.inkDim),
              const KkSpacer(),
              Semantics(
                container: true,
                label: 'Item $shown of $_count',
                child: ExcludeSemantics(
                  child: KkBox(
                    padding: EdgeInsets.only(right: m.space1),
                    child: KkText.num(
                      '${_two(shown)} / ${_two(_count)}',
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

/// Left and Right on the row itself. While something inside the row has the
/// focus the keys are left to it (and to the focus traversal).
class _KkCarouselStep extends Action<_CarouselIntent> {
  _KkCarouselStep(this.state);

  final _KkCarouselState state;

  @override
  bool isEnabled(_CarouselIntent intent) => state._trackNode.hasPrimaryFocus;

  @override
  Object? invoke(_CarouselIntent intent) {
    if (intent.delta < 0) {
      state._previous();
    } else {
      state._next();
    }
    return null;
  }
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
                child: ExcludeSemantics(
                  excluding: item.semanticLabel != null,
                  child: KkBox(
                    fill: c.bg000,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: KkText.num(caption, size: 11, weight: FontWeight.w500, color: c.ink),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (item.onPressed == null) {
      return Semantics(container: true, label: item.semanticLabel, child: card(const KkStates()));
    }
    return KkPressable(
      onPressed: item.onPressed,
      semanticLabel: item.semanticLabel,
      builder: (BuildContext context, KkStates raw) => card(KkStateOverride.resolve(context, raw)),
    );
  }
}

/// Scroll physics that settle on a card edge: the row always rests with a
/// card at its leading edge, or at the very end.
///
/// A fling lands on the rest position nearest to where it would have stopped
/// by itself, and always leaves the card it started on.
class _KkSnapPhysics extends ScrollPhysics {
  const _KkSnapPhysics({required this.extentOf, super.parent});

  /// The card pitch, asked for each time: a scroll position keeps the physics
  /// it was created with, and the pitch can change under it.
  final double Function() extentOf;

  double get extent => extentOf();

  /// Long enough for any fling to have stopped, in seconds.
  static const double _settled = 600;

  /// How close to a card edge counts as on it.
  static const double _slop = 0.5;

  @override
  _KkSnapPhysics applyTo(ScrollPhysics? ancestor) => _KkSnapPhysics(extentOf: extentOf, parent: buildParent(ancestor));

  /// The rest position nearest to [x]: a card edge, or the very end, which
  /// stands in for every card that cannot reach the leading edge.
  double _nearest(double x, double min, double max) {
    final double extent = this.extent;
    final double before = math.max(min, (x / extent).floorToDouble() * extent);
    final double after = math.min(max, before + extent);
    return x - before < after - x ? before : after;
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final double min = position.minScrollExtent;
    final double max = position.maxScrollExtent;
    final double pixels = position.pixels;
    // Out of range, or pushed against an end: the parent physics decide.
    if (pixels < min || pixels > max || (velocity <= 0.0 && pixels <= min) || (velocity >= 0.0 && pixels >= max)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final Tolerance tolerance = toleranceFor(position);
    final double extent = this.extent;
    // Where the fling would stop by itself, and the rest position nearest to it.
    final Simulation? free = super.createBallisticSimulation(position, velocity);
    final double rest = free?.x(_settled) ?? pixels;
    double target = _nearest(rest.clamp(min, max), min, max);
    if (velocity > tolerance.velocity) {
      target = math.max(target, math.min(max, ((pixels + _slop) / extent).floorToDouble() * extent + extent));
    } else if (velocity < -tolerance.velocity) {
      target = math.min(target, math.max(min, ((pixels - _slop) / extent).ceilToDouble() * extent - extent));
    }
    if ((target - pixels).abs() < tolerance.distance) return null;
    // A fling that carries a card or more keeps its own deceleration,
    // stretched to end on the target. A weaker one is pulled in by a spring.
    if (free != null && (rest - pixels).abs() >= extent && (target - pixels) * (rest - pixels) > 0) {
      return _KkStretchedSimulation(free, start: pixels, end: target, rest: rest, tolerance: tolerance);
    }
    return ScrollSpringSimulation(spring, pixels, target, velocity, tolerance: tolerance);
  }

  @override
  bool get allowImplicitScrolling => false;
}

/// The motion of [free], which runs from [start] to `rest`, stretched so that
/// it ends on [end] instead.
class _KkStretchedSimulation extends Simulation {
  _KkStretchedSimulation(this.free, {required this.start, required this.end, required double rest, super.tolerance})
    : _scale = (end - start) / (rest - start);

  final Simulation free;
  final double start;
  final double end;
  final double _scale;

  @override
  double x(double time) => isDone(time) ? end : start + (free.x(time) - start) * _scale;

  @override
  double dx(double time) => isDone(time) ? 0.0 : free.dx(time) * _scale;

  @override
  bool isDone(double time) => free.isDone(time);
}
