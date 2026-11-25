import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/level.dart';
import '../foundation/theme.dart';
import '../layout/box.dart';
import '../layout/layers.dart';
import '../motion/entrances.dart';
import '../motion/loops.dart';
import '../widgets/pressable.dart';
import 'geometry.dart';
import 'layered_layout.dart';
import 'layout.dart';
import 'metrics.dart';
import 'model.dart';
import 'painter.dart';
import 'router.dart';

/// How a diagram is fitted into the space it is given.
enum KkDiagramFit {
  /// Shrink the diagram until all of it shows. It is never enlarged.
  contain,

  /// Draw at natural size; what does not fit is clipped (and can be reached
  /// by panning an interactive view).
  none,
}

/// Holds the pan and zoom of a [KkDiagramView] and moves them.
///
/// Zoom 1 is the fitted size. Zoom is kept between [minZoom] and [maxZoom],
/// and the diagram cannot be dragged out of sight.
class KkDiagramController extends ChangeNotifier {
  KkDiagramController({this.minZoom = 0.5, this.maxZoom = 4})
    : assert(minZoom > 0),
      assert(maxZoom >= minZoom);

  final double minZoom;
  final double maxZoom;

  double _zoom = 1;
  Offset _pan = Offset.zero;
  Size _view = Size.zero;
  Size _content = Size.zero;
  double _fit = 1;
  Offset _base = Offset.zero;

  /// The zoom factor on top of the fitted size.
  double get zoom => _zoom;

  /// How far the diagram has been dragged, in view pixels.
  Offset get pan => _pan;

  /// Screen pixels per diagram pixel: the fit scale times [zoom].
  double get scale => _fit * _zoom;

  /// Whether the view is at its resting position.
  bool get isReset => _zoom == 1 && _pan == Offset.zero;

  /// The size of the view, once it has been laid out.
  Size get viewSize => _view;

  /// The part of the diagram's own space that shows in the view.
  Rect get visible => _view.isEmpty
      ? Offset.zero & _content
      : Rect.fromPoints(toScene(Offset.zero), toScene(_view.bottomRight(Offset.zero)));

  /// Called by the view when it has been laid out.
  void attach({required Size view, required Size content, required double fit, required Alignment alignment}) {
    _view = view;
    _content = content;
    _fit = fit;
    _base = alignment.alongOffset(Offset(view.width - content.width * fit, view.height - content.height * fit));
    _pan = _clamped(_pan);
  }

  Offset _clamped(Offset pan) {
    if (_view.isEmpty) return pan;
    final double w = _content.width * scale;
    final double h = _content.height * scale;
    // What zooming adds is spread around the alignment point; panning may
    // move the diagram until only a margin of it is left in view.
    final double mx = math.min(32, w / 2);
    final double my = math.min(32, h / 2);
    final double x = pan.dx.clamp(mx - w - _base.dx, _view.width - mx - _base.dx);
    final double y = pan.dy.clamp(my - h - _base.dy, _view.height - my - _base.dy);
    return Offset(x, y);
  }

  /// The transform from diagram space to view space.
  Matrix4 get transform {
    final Offset o = _base + _pan;
    return Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, o.dx)
      ..setEntry(1, 3, o.dy);
  }

  /// The diagram point under the view point [p].
  Offset toScene(Offset p) => (p - _base - _pan) / scale;

  /// The view point of the diagram point [p].
  Offset toView(Offset p) => p * scale + _base + _pan;

  /// Sets the zoom, keeping the diagram point under [focal] (a view point,
  /// by default the middle of the view) where it is.
  void zoomTo(double zoom, {Offset? focal}) {
    final double next = zoom.clamp(minZoom, maxZoom);
    if (next == _zoom) return;
    final Offset f = focal ?? _view.center(Offset.zero);
    final Offset scene = toScene(f);
    _zoom = next;
    _pan = _clamped(f - _base - scene * scale);
    notifyListeners();
  }

  /// Multiplies the zoom by [factor].
  void zoomBy(double factor, {Offset? focal}) => zoomTo(_zoom * factor, focal: focal);

  /// Drags the diagram by [delta] view pixels.
  void panBy(Offset delta) {
    final Offset next = _clamped(_pan + delta);
    if (next == _pan) return;
    _pan = next;
    notifyListeners();
  }

  /// Back to the fitted size and position.
  void reset() {
    if (isReset) return;
    _zoom = 1;
    _pan = Offset.zero;
    notifyListeners();
  }
}

/// Draws a [KkDiagram].
///
/// The view places the diagram with [layout], routes its wires with [router]
/// and paints it on a canvas: symbols with their code and label, wires with
/// 45° bends, status flags, flow marks running along live wires and a
/// blinking halo round every critical node. Nodes pop in one after another
/// when the view first appears, then the wires are drawn.
///
/// Every node is a control: it can be hovered, tapped, reached with Tab and
/// the arrow keys and activated with Enter. A tap selects the node, which
/// shows a focus ring and an info plate, and calls [onSelected]; tapping it
/// again clears the selection. Pass [selected] to control the selection from
/// outside.
///
/// With [interactive] the diagram can be dragged, zoomed with the wheel or a
/// pinch, and reset through its [controller] (or the `0` key).
class KkDiagramView extends StatefulWidget {
  const KkDiagramView({
    super.key,
    required this.diagram,
    this.layout = const KkLayeredLayout(),
    this.router,
    this.metrics = const KkNodeMetrics(),
    this.padding = const EdgeInsets.all(16),
    this.fit = KkDiagramFit.contain,
    this.alignment = Alignment.center,
    this.interactive = false,
    this.controller,
    this.selectable = true,
    this.selected,
    this.onSelected,
    this.onNodeTap,
    this.showInfo = true,
    this.infoBuilder,
    this.arrows = true,
    this.ground,
    this.animate = true,
    this.semanticLabel,
  });

  final KkDiagram diagram;

  /// Where the nodes go. Defaults to the layered flow layout.
  final KkDiagramLayout layout;

  /// How the wires run. Defaults to the layout's own router.
  final KkEdgeRouter? router;

  /// Symbol and text sizes, with a per-node size hook.
  final KkNodeMetrics metrics;

  /// Space around the diagram.
  final EdgeInsets padding;
  final KkDiagramFit fit;

  /// Where the diagram sits when it is smaller than the view.
  final Alignment alignment;

  /// Let the user drag and zoom the diagram.
  final bool interactive;

  /// Pan and zoom state. The view makes its own when this is null.
  final KkDiagramController? controller;

  /// Whether tapping a node selects it.
  final bool selectable;

  /// Id of the selected node. When this changes the view follows.
  final String? selected;

  /// Called with the id of the newly selected node, or null when the
  /// selection is cleared.
  final ValueChanged<String?>? onSelected;

  /// Called for every tap on a node.
  final ValueChanged<KkDiagramNode>? onNodeTap;

  /// Show the info plate of the selected node.
  final bool showInfo;

  /// The lines of the info plate. By default a node's own `info`, or its
  /// label, status and wire counts.
  final List<String> Function(KkDiagramNode node)? infoBuilder;

  /// Draw arrow heads.
  final bool arrows;

  /// The colour behind the diagram: symbols are filled with it. Defaults to
  /// the panel colour (bg-100).
  final Color? ground;

  /// Play the entrance (nodes pop in, wires are drawn).
  final bool animate;

  /// Announced for the whole diagram. Defaults to a count of nodes and wires.
  final String? semanticLabel;

  @override
  State<KkDiagramView> createState() => _KkDiagramViewState();
}

class _KkDiagramViewState extends State<KkDiagramView> {
  KkDiagramGeometry? _geometry;
  KkNodeMetrics? _geometryMetrics;
  final Map<String, FocusNode> _focusNodes = <String, FocusNode>{};
  KkDiagramController? _ownController;
  String? _hovered;
  String? _focused;
  String? _selected;
  double _zoomStart = 1;

  KkDiagramController get _controller => widget.controller ?? (_ownController ??= KkDiagramController());

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
  }

  @override
  void didUpdateWidget(KkDiagramView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) _selected = widget.selected;
    if (widget.diagram != oldWidget.diagram ||
        widget.layout != oldWidget.layout ||
        widget.router != oldWidget.router) {
      _geometry = null;
      if (_selected != null && widget.diagram.nodeById(_selected!) == null) _selected = null;
      if (_hovered != null && widget.diagram.nodeById(_hovered!) == null) _hovered = null;
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    for (final FocusNode node in _focusNodes.values) {
      node.dispose();
    }
    _ownController?.dispose();
    super.dispose();
  }

  void _onHighlightMode(FocusHighlightMode mode) => _syncFocus();

  void _syncFocus() {
    if (!mounted) return;
    String? id;
    if (FocusManager.instance.highlightMode == FocusHighlightMode.traditional) {
      for (final MapEntry<String, FocusNode> e in _focusNodes.entries) {
        if (e.value.hasPrimaryFocus) id = e.key;
      }
    }
    if (id != _focused) setState(() => _focused = id);
  }

  FocusNode _focusNodeFor(String id) =>
      _focusNodes.putIfAbsent(id, () => FocusNode(debugLabel: 'KkDiagram node $id')..addListener(_syncFocus));

  void _pruneFocusNodes() {
    final List<String> gone = <String>[
      for (final String id in _focusNodes.keys)
        if (widget.diagram.nodeById(id) == null) id,
    ];
    if (gone.isEmpty) return;
    final List<FocusNode> nodes = <FocusNode>[for (final String id in gone) _focusNodes.remove(id)!];
    // Their widgets are still mounted during this build: let go afterwards.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      for (final FocusNode node in nodes) {
        node.dispose();
      }
    });
  }

  KkDiagramGeometry _resolve(KkNodeMetrics metrics) {
    final KkDiagramGeometry? cached = _geometry;
    if (cached != null && _geometryMetrics == metrics) return cached;
    _geometryMetrics = metrics;
    return _geometry = widget.layout.compute(widget.diagram, metrics: metrics, router: widget.router);
  }

  void _tap(KkDiagramNode node) {
    widget.onNodeTap?.call(node);
    if (!widget.selectable) return;
    final String? next = _selected == node.id ? null : node.id;
    setState(() => _selected = next);
    widget.onSelected?.call(next);
  }

  void _hover(String id, bool inside) {
    final String? next = inside ? id : (_hovered == id ? null : _hovered);
    if (next != _hovered) setState(() => _hovered = next);
  }

  String _nodeLabel(KkDiagramNode node) {
    final StringBuffer b = StringBuffer(node.text);
    final String? label = node.label;
    if (label != null && label.isNotEmpty) b.write(', $label');
    final KkLevel? level = node.level;
    if (level != null) b.write(', ${level.word}');
    return b.toString();
  }

  void _onSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (PointerSignalEvent e) {
      final PointerScrollEvent scroll = e as PointerScrollEvent;
      if (scroll.scrollDelta.dy == 0) return;
      _controller.zoomBy(scroll.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1, focal: scroll.localPosition);
    });
  }

  @override
  Widget build(BuildContext context) {
    final KeikaiThemeData theme = KeikaiTheme.of(context);
    final KkDiagram diagram = widget.diagram;
    final KkNodeMetrics metrics = widget.metrics.copyWith(textScale: widget.metrics.textScale * theme.type.scale);
    final KkDiagramGeometry geometry = _resolve(metrics);
    _pruneFocusNodes();
    final EdgeInsets padding = widget.padding;
    final Size natural = Size(
      math.max(1, geometry.size.width + padding.horizontal),
      math.max(1, geometry.size.height + padding.vertical),
    );
    final KkDiagramController controller = _controller;
    final KkDiagramPainter painter = KkDiagramPainter(
      geometry: geometry,
      colors: theme.colors,
      type: theme.type,
      metrics: metrics,
      ground: widget.ground,
      arrows: widget.arrows,
      hovered: _hovered,
      focused: _focused,
      selected: _selected,
      origin: padding.topLeft,
    );
    final KkDiagramEntrance entrance = KkDiagramEntrance(nodes: diagram.nodes.length, wires: diagram.edges.length);
    final String? selected = _selected;
    final KkDiagramNode? selectedNode = selected == null ? null : diagram.nodeById(selected);
    final List<String>? info = selectedNode == null ? null : widget.infoBuilder?.call(selectedNode);

    Widget content = KkOneShot(
      duration: entrance.total,
      enabled: widget.animate,
      builder: (BuildContext context, Animation<double> progress, bool done, Widget? child) {
        return KkLayers(
          children: <Widget>[
            KkPositioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _WireLayer(painter, entrance, progress, controller),
                ),
              ),
            ),
            if (painter.moves)
              KkPositioned.fill(
                child: KkLoop(
                  builder: (BuildContext context, ValueListenable<Duration> time) => CustomPaint(
                    painter: _MovingLayer(painter, entrance, progress, controller, time),
                  ),
                ),
              ),
            KkPositioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _NodeLayer(painter, entrance, progress, controller, info, widget.showInfo),
                ),
              ),
            ),
            for (final KkDiagramNode node in diagram.nodes)
              if (geometry.nodes[node.id] case final KkNodePlacement place)
                KkPositioned(
                  left: place.bounds.left + padding.left,
                  top: place.bounds.top + padding.top,
                  width: math.max(place.bounds.width, 1),
                  height: math.max(place.bounds.height, 1),
                  child: KkPressable(
                    key: ValueKey<String>('kk-diagram-node-${node.id}'),
                    focusNode: _focusNodeFor(node.id),
                    semanticLabel: _nodeLabel(node),
                    selected: _selected == node.id,
                    excludeSemantics: true,
                    onPressed: () => _tap(node),
                    onHoverChanged: (bool inside) => _hover(node.id, inside),
                    builder: (BuildContext context, KkStates states) => const KkBox(),
                  ),
                ),
          ],
        );
      },
    );

    content = _KkDiagramViewport(
      controller: controller,
      natural: natural,
      fit: widget.fit,
      alignment: widget.alignment,
      child: content,
    );

    content = Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.arrowLeft): const DirectionalFocusIntent(TraversalDirection.left),
        const SingleActivator(LogicalKeyboardKey.arrowRight): const DirectionalFocusIntent(TraversalDirection.right),
        const SingleActivator(LogicalKeyboardKey.arrowUp): const DirectionalFocusIntent(TraversalDirection.up),
        const SingleActivator(LogicalKeyboardKey.arrowDown): const DirectionalFocusIntent(TraversalDirection.down),
        if (widget.interactive) ...<ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.equal): const _ZoomIntent(1.25),
          const SingleActivator(LogicalKeyboardKey.add): const _ZoomIntent(1.25),
          const SingleActivator(LogicalKeyboardKey.minus): const _ZoomIntent(0.8),
          const SingleActivator(LogicalKeyboardKey.digit0): const _ZoomIntent(0),
        },
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          DirectionalFocusIntent: DirectionalFocusAction(),
          _ZoomIntent: CallbackAction<_ZoomIntent>(
            onInvoke: (_ZoomIntent intent) {
              if (intent.factor == 0) {
                controller.reset();
              } else {
                controller.zoomBy(intent.factor);
              }
              return null;
            },
          ),
        },
        child: FocusTraversalGroup(child: content),
      ),
    );

    if (widget.interactive) {
      content = Listener(
        onPointerSignal: _onSignal,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (ScaleStartDetails details) => _zoomStart = controller.zoom,
          onScaleUpdate: (ScaleUpdateDetails details) {
            if (details.scale != 1) controller.zoomTo(_zoomStart * details.scale, focal: details.localFocalPoint);
            controller.panBy(details.focalPointDelta);
          },
          child: content,
        ),
      );
    }

    return Semantics(
      container: true,
      label:
          widget.semanticLabel ??
          'Diagram, ${diagram.nodes.length} nodes, ${diagram.edges.length} wires',
      child: content,
    );
  }
}

class _ZoomIntent extends Intent {
  const _ZoomIntent(this.factor);

  /// Multiplier for the zoom; 0 means reset.
  final double factor;
}

class _WireLayer extends CustomPainter {
  _WireLayer(this.painter, this.entrance, this.progress, this.controller)
    : super(repaint: Listenable.merge(<Listenable>[progress, controller]));

  final KkDiagramPainter painter;
  final KkDiagramEntrance entrance;
  final Animation<double> progress;
  final KkDiagramController controller;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = progress.value;
    painter.paintWires(canvas, scale: controller.scale, progress: t >= 1 ? null : (int i) => entrance.wire(i, t));
  }

  @override
  bool shouldRepaint(_WireLayer old) => old.painter != painter || old.progress != progress || old.entrance != entrance;
}

class _MovingLayer extends CustomPainter {
  _MovingLayer(this.painter, this.entrance, this.progress, this.controller, this.time)
    : super(repaint: Listenable.merge(<Listenable>[progress, controller, time]));

  final KkDiagramPainter painter;
  final KkDiagramEntrance entrance;
  final Animation<double> progress;
  final KkDiagramController controller;
  final ValueListenable<Duration> time;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = progress.value;
    final double scale = controller.scale;
    painter.paintFlow(canvas, time.value, scale: scale, progress: t >= 1 ? null : (int i) => entrance.wire(i, t));
    painter.paintHalos(canvas, time.value, scale: scale, progress: t >= 1 ? null : (int i) => entrance.node(i, t));
  }

  @override
  bool shouldRepaint(_MovingLayer old) =>
      old.painter != painter || old.progress != progress || old.time != time || old.entrance != entrance;
}

class _NodeLayer extends CustomPainter {
  _NodeLayer(this.painter, this.entrance, this.progress, this.controller, this.info, this.showInfo)
    : super(repaint: Listenable.merge(<Listenable>[progress, controller]));

  final KkDiagramPainter painter;
  final KkDiagramEntrance entrance;
  final Animation<double> progress;
  final KkDiagramController controller;
  final List<String>? info;
  final bool showInfo;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = progress.value;
    final double scale = controller.scale;
    painter.paintLabels(canvas, progress: t >= 1 ? null : (int i) => entrance.wire(i, t));
    painter.paintNodes(canvas, scale: scale, progress: t >= 1 ? null : (int i) => entrance.node(i, t));
    if (t >= 1) {
      painter.paintSelection(canvas, scale: scale, info: info, plate: showInfo, view: controller.visible);
    }
  }

  @override
  bool shouldRepaint(_NodeLayer old) =>
      old.painter != painter ||
      old.progress != progress ||
      old.entrance != entrance ||
      old.showInfo != showInfo ||
      !listEquals(old.info, info);
}

class _KkDiagramViewport extends SingleChildRenderObjectWidget {
  const _KkDiagramViewport({
    required this.controller,
    required this.natural,
    required this.fit,
    required this.alignment,
    super.child,
  });

  final KkDiagramController controller;
  final Size natural;
  final KkDiagramFit fit;
  final Alignment alignment;

  @override
  RenderKkDiagramViewport createRenderObject(BuildContext context) =>
      RenderKkDiagramViewport(controller: controller, natural: natural, fit: fit, alignment: alignment);

  @override
  void updateRenderObject(BuildContext context, RenderKkDiagramViewport renderObject) {
    renderObject
      ..controller = controller
      ..natural = natural
      ..fit = fit
      ..alignment = alignment;
  }
}

/// The render object that fits a diagram into its box and applies the pan
/// and zoom of a [KkDiagramController].
class RenderKkDiagramViewport extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  RenderKkDiagramViewport({
    required KkDiagramController controller,
    required Size natural,
    KkDiagramFit fit = KkDiagramFit.contain,
    Alignment alignment = Alignment.center,
  }) : _controller = controller,
       _natural = natural,
       _fit = fit,
       _alignment = alignment;

  KkDiagramController _controller;
  KkDiagramController get controller => _controller;
  set controller(KkDiagramController value) {
    if (value == _controller) return;
    if (attached) _controller.removeListener(_onMoved);
    _controller = value;
    if (attached) _controller.addListener(_onMoved);
    markNeedsLayout();
  }

  Size _natural;
  Size get natural => _natural;
  set natural(Size value) {
    if (value == _natural) return;
    _natural = value;
    markNeedsLayout();
  }

  KkDiagramFit _fit;
  KkDiagramFit get fit => _fit;
  set fit(KkDiagramFit value) {
    if (value == _fit) return;
    _fit = value;
    markNeedsLayout();
  }

  Alignment _alignment;
  Alignment get alignment => _alignment;
  set alignment(Alignment value) {
    if (value == _alignment) return;
    _alignment = value;
    markNeedsLayout();
  }

  void _onMoved() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.addListener(_onMoved);
  }

  @override
  void detach() {
    _controller.removeListener(_onMoved);
    super.detach();
  }

  double _fitScale(BoxConstraints constraints) {
    if (_fit != KkDiagramFit.contain) return 1;
    double s = 1;
    if (constraints.hasBoundedWidth && _natural.width > 0) s = math.min(s, constraints.maxWidth / _natural.width);
    if (constraints.hasBoundedHeight && _natural.height > 0) s = math.min(s, constraints.maxHeight / _natural.height);
    return s;
  }

  Size _sizeFor(BoxConstraints constraints) => constraints.constrain(_natural * _fitScale(constraints));

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  // Like a picture: the widest the diagram is drawn at this height.
  @override
  double computeMaxIntrinsicWidth(double height) =>
      height.isFinite && _natural.height > 0 && _fit == KkDiagramFit.contain
      ? _natural.width * math.min(1, height / _natural.height)
      : _natural.width;

  @override
  double computeMinIntrinsicHeight(double width) =>
      width.isFinite && _natural.width > 0 && _fit == KkDiagramFit.contain
      ? _natural.height * math.min(1, width / _natural.width)
      : _natural.height;

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sizeFor(constraints);

  // A diagram is a picture that is scaled and moved inside the viewport: it
  // has no line of text to sit on, measured or laid out.
  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) => null;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => null;

  @override
  void performLayout() {
    child?.layout(BoxConstraints.tight(_natural));
    size = _sizeFor(constraints);
    _controller.attach(view: size, content: _natural, fit: _fitScale(constraints), alignment: _alignment);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) => transform.multiply(_controller.transform);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final RenderBox? c = child;
    if (c == null) return false;
    return result.addWithPaintTransform(
      transform: _controller.transform,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) => c.hitTest(result, position: transformed),
    );
  }

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();
  final LayerHandle<TransformLayer> _transformLayer = LayerHandle<TransformLayer>();

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? c = child;
    if (c == null) {
      _clipLayer.layer = null;
      _transformLayer.layer = null;
      return;
    }
    _clipLayer.layer = context.pushClipRect(needsCompositing, offset, Offset.zero & size, (
      PaintingContext context,
      Offset offset,
    ) {
      _transformLayer.layer = context.pushTransform(
        needsCompositing,
        offset,
        _controller.transform,
        (PaintingContext context, Offset offset) => context.paintChild(c, offset),
        oldLayer: _transformLayer.layer,
      );
    }, oldLayer: _clipLayer.layer);
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    _transformLayer.layer = null;
    super.dispose();
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => Offset.zero & size;
}
