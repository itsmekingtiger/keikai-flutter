import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Makes a child that would fill the available width take only the width its
/// content needs, unless the parent fixes the width.
///
/// Instruments (readout, meter, timer) use it: side by side in a row or a
/// wrap they are as wide as their content (never narrower than their
/// minimum), and inside a column or a grid cell they fill the width they are
/// given.
class KkHugWidth extends SingleChildRenderObjectWidget {
  const KkHugWidth({super.key, super.child});

  @override
  RenderKkHugWidth createRenderObject(BuildContext context) => RenderKkHugWidth();
}

/// The render object behind [KkHugWidth].
class RenderKkHugWidth extends RenderProxyBox {
  RenderKkHugWidth([super.child]);

  BoxConstraints _measure(BoxConstraints c) =>
      BoxConstraints(minHeight: c.minHeight, maxHeight: c.maxHeight);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final RenderBox? c = child;
    if (c == null) return constraints.smallest;
    if (constraints.hasTightWidth) return c.getDryLayout(constraints);
    final double width = constraints.constrainWidth(c.getDryLayout(_measure(constraints)).width);
    return c.getDryLayout(constraints.tighten(width: width));
  }

  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    final RenderBox? c = child;
    if (c == null) return null;
    if (constraints.hasTightWidth) return c.getDryBaseline(constraints, baseline);
    final double width = constraints.constrainWidth(c.getDryLayout(_measure(constraints)).width);
    return c.getDryBaseline(constraints.tighten(width: width), baseline);
  }

  @override
  void performLayout() {
    final RenderBox? c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    if (!constraints.hasTightWidth) {
      // Measure at any width, then lay out at exactly the measured width.
      c.layout(_measure(constraints), parentUsesSize: true);
      final double width = constraints.constrainWidth(c.size.width);
      c.layout(constraints.tighten(width: width), parentUsesSize: true);
    } else {
      c.layout(constraints, parentUsesSize: true);
    }
    size = constraints.constrain(c.size);
  }
}
