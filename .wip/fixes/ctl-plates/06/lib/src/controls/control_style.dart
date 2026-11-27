import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/colors.dart';
import '../layout/box.dart';
import '../painting/shapes.dart';
import '../widgets/pressable.dart';

/// Colour overrides for a plated control ([KkButton], [KkIconButton]).
///
/// A null field keeps the colour the control's variant and state give it.
/// The `hover*` fields apply while a pointer is over the control and fall
/// back to the plain field when null.
///
/// A button on the full-screen alarm plate, for example, is black with alert
/// ink: `KkPlateStyle(edge: bg000, fill: bg000, ink: alert)`.
@immutable
class KkPlateStyle {
  const KkPlateStyle({this.edge, this.fill, this.ink, this.hoverEdge, this.hoverFill, this.hoverInk});

  /// The 1px outline of the plate.
  final Color? edge;

  /// The plate itself.
  final Color? fill;

  /// Text and icon colour.
  final Color? ink;
  final Color? hoverEdge;
  final Color? hoverFill;
  final Color? hoverInk;

  @override
  bool operator ==(Object other) =>
      other is KkPlateStyle &&
      other.edge == edge &&
      other.fill == fill &&
      other.ink == ink &&
      other.hoverEdge == hoverEdge &&
      other.hoverFill == hoverFill &&
      other.hoverInk == hoverInk;

  @override
  int get hashCode => Object.hash(edge, fill, ink, hoverEdge, hoverFill, hoverInk);
}

/// Shows the controls below it as hovered, focused or pressed without a
/// pointer or a keyboard.
///
/// It exists for catalogues, screenshots and tests: a sheet can lay the hover
/// and focus looks of a button side by side. It never makes a disabled control
/// look live.
class KkStateOverride extends InheritedWidget {
  const KkStateOverride({
    super.key,
    this.hovered = false,
    this.focused = false,
    this.pressed = false,
    required super.child,
  });

  final bool hovered;
  final bool focused;
  final bool pressed;

  /// [states] with the nearest override folded in.
  static KkStates resolve(BuildContext context, KkStates states) {
    final KkStateOverride? o = context.dependOnInheritedWidgetOfExactType<KkStateOverride>();
    if (o == null || !states.enabled) return states;
    return KkStates(
      hovered: states.hovered || o.hovered,
      focused: states.focused || o.focused,
      pressed: states.pressed || o.pressed,
    );
  }

  @override
  bool updateShouldNotify(KkStateOverride oldWidget) =>
      oldWidget.hovered != hovered || oldWidget.focused != focused || oldWidget.pressed != pressed;
}

/// The plate of a control: a [KkSurface], except that a clear fill under a
/// visible edge is drawn as a hollow outline.
///
/// A surface is two stacked plates, edge colour under fill colour, so with a
/// clear fill the whole plate would show in the edge colour. A disabled
/// filled icon button (signal edge, no fill) would then read as a lit block.
/// Here it is what "no fill" means: an empty frame.
class KkPlate extends StatelessWidget {
  const KkPlate({
    super.key,
    this.shape = const KkShape.rect(),
    this.edge,
    this.fill,
    this.edgeWidth = 1,
    this.glow,
    this.clip = false,
    this.child,
  });

  final KkShape shape;
  final Color? edge;
  final Color? fill;
  final double edgeWidth;
  final KkGlow? glow;

  /// Clip the child to the shape.
  final bool clip;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final Color? e = edge;
    final bool hollow = e != null && e.a > 0 && edgeWidth > 0 && (fill?.a ?? 0) <= 0;
    return KkSurface(
      shape: shape,
      edge: hollow ? null : e,
      fill: fill,
      edgeWidth: edgeWidth,
      glow: glow,
      clip: clip,
      child: CustomPaint(
        painter: hollow ? _OutlinePainter(shape: shape, color: e, width: edgeWidth) : null,
        child: child,
      ),
    );
  }
}

class _OutlinePainter extends CustomPainter {
  const _OutlinePainter({required this.shape, required this.color, required this.width});

  final KkShape shape;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Rect inner = rect.deflate(width);
    if (rect.isEmpty) return;
    final Path ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(shape.path(rect), Offset.zero);
    if (inner.width > 0 && inner.height > 0) ring.addPath(shape.path(inner), Offset.zero);
    canvas.drawPath(ring, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_OutlinePainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.color != color || oldDelegate.width != width;
}

/// Rounds the width of its child up to a whole pixel: the content of a plate
/// that is as wide as its text.
///
/// Text is never a whole number of pixels wide, so a tag, a key cap or a
/// button that hugs its text would end between two pixels and its 1px edge
/// would be smeared over both. A browser snaps such a box to the pixel grid
/// when it paints it. Here the content is rounded up instead, by less than a
/// pixel: the child keeps its own width at the left, and the room that is
/// added is at the right.
///
/// The padding and the border of the plate around it are whole numbers, so
/// the plate ends on a whole pixel wherever it starts on one. A child that is
/// given its width, or more text than there is room for, is left as it is.
///
/// The pixels are logical ones, which are whole device pixels at the pixel
/// ratios 1, 2 and 3. That keeps the layout the same on every display.
class KkWholeWidth extends SingleChildRenderObjectWidget {
  const KkWholeWidth({super.key, super.child});

  @override
  RenderKkWholeWidth createRenderObject(BuildContext context) => RenderKkWholeWidth();
}

/// The render object behind [KkWholeWidth].
class RenderKkWholeWidth extends RenderProxyBox {
  RenderKkWholeWidth([super.child]);

  /// [width] rounded up to a whole pixel. A width that is whole but for the
  /// noise of adding up fractions is left alone, and so is one that is not
  /// finite.
  static double _whole(double width) {
    if (!width.isFinite) return width;
    final double up = (width - 0.001).ceilToDouble();
    return up < width ? width : up;
  }

  @override
  double computeMinIntrinsicWidth(double height) => _whole(super.computeMinIntrinsicWidth(height));

  @override
  double computeMaxIntrinsicWidth(double height) => _whole(super.computeMaxIntrinsicWidth(height));

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final RenderBox? c = child;
    if (c == null) return constraints.smallest;
    final Size s = c.getDryLayout(constraints);
    return constraints.constrain(Size(_whole(s.width), s.height));
  }

  @override
  void performLayout() {
    final RenderBox? c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(Size(_whole(c.size.width), c.size.height));
  }
}
