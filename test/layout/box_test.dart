import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import 'layout_util.dart';

const Color _red = Color(0xFFFF0000);
const Color _blue = Color(0xFF0000FF);

void main() {
  group('KkBox layout', () {
    testWidgets('border and padding take space inside the box (border-box)', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        KkBox(
          key: const ValueKey<String>('box'),
          width: 100,
          height: 36,
          edges: KkEdges.line(_red),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: box('c'),
        ),
      );
      expect(rectOf(tester, 'box').size, const Size(100, 36));
      expect(rectOf(tester, 'c'), const Rect.fromLTWH(13, 1, 74, 34));
    });

    testWidgets('unequal border widths inset each side by its own width', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        KkBox(
          width: 100,
          height: 50,
          edges: const KkEdges(top: KkSide(_red, width: 4), left: KkSide(_red, width: 2)),
          child: box('c'),
        ),
      );
      expect(rectOf(tester, 'c'), const Rect.fromLTWH(2, 4, 98, 46));
    });

    testWidgets('without a child it is as large as its insets, or its fixed size', (WidgetTester tester) async {
      await pumpRaw(tester, const KkBox(key: ValueKey<String>('box')));
      expect(rectOf(tester, 'box').size, Size.zero);
      await pumpRaw(tester, const KkBox(key: ValueKey<String>('box'), padding: EdgeInsets.all(8)));
      expect(rectOf(tester, 'box').size, const Size(16, 16));
      await pumpRaw(tester, const KkBox(key: ValueKey<String>('box'), width: 40, height: 20));
      expect(rectOf(tester, 'box').size, const Size(40, 20));
      await pumpRaw(tester, const KkBox(key: ValueKey<String>('box'), alignment: Alignment.center));
      expect(rectOf(tester, 'box').size, const Size(800, 600));
    });

    testWidgets('hugs its child when it has no alignment', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        KkBox(key: const ValueKey<String>('box'), padding: const EdgeInsets.all(8), child: box('c', 40, 20)),
      );
      expect(rectOf(tester, 'box').size, const Size(56, 36));
      expect(rectOf(tester, 'c').topLeft, const Offset(8, 8));
    });

    testWidgets('with an alignment it fills bounded space and places the child', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        KkBox(key: const ValueKey<String>('box'), alignment: Alignment.center, child: box('c', 40, 20)),
      );
      expect(rectOf(tester, 'box').size, const Size(800, 600));
      expect(rectOf(tester, 'c'), const Rect.fromLTWH(380, 290, 40, 20));
      await pumpRaw(
        tester,
        KkBox(
          key: const ValueKey<String>('box'),
          width: 100,
          height: 60,
          padding: const EdgeInsets.all(10),
          alignment: Alignment.bottomRight,
          child: box('c', 40, 20),
        ),
      );
      expect(rectOf(tester, 'c'), const Rect.fromLTWH(50, 30, 40, 20));
    });

    testWidgets('with an alignment and no bound it hugs the child', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        UnconstrainedBox(
          alignment: Alignment.topLeft,
          child: KkBox(
            key: const ValueKey<String>('box'),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(4),
            child: box('c', 40, 20),
          ),
        ),
      );
      expect(rectOf(tester, 'box').size, const Size(48, 28));
    });

    testWidgets('min and max sizes', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        KkBox(key: const ValueKey<String>('box'), minWidth: 100, minHeight: 50, child: box('c', 40, 20)),
      );
      expect(rectOf(tester, 'box').size, const Size(100, 50));
      await pumpRaw(
        tester,
        KkBox(key: const ValueKey<String>('box'), maxWidth: 30, maxHeight: 10, child: box('c', 40, 20)),
      );
      expect(rectOf(tester, 'box').size, const Size(30, 10));
      // The parent's constraints win over the box's own.
      await pumpRaw(
        tester,
        const SizedBox(width: 60, height: 60, child: KkBox(key: ValueKey<String>('box'), width: 200, height: 10)),
      );
      expect(rectOf(tester, 'box').size, const Size(60, 60));
    });

    testWidgets('infinite width and height expand to the parent', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        const SizedBox(
          width: 300,
          height: 200,
          child: KkBox(
            alignment: Alignment.topLeft,
            child: KkBox(key: ValueKey<String>('box'), width: double.infinity, height: double.infinity),
          ),
        ),
      );
      expect(rectOf(tester, 'box').size, const Size(300, 200));
    });

    testWidgets('padding larger than the box does not throw', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        KkBox(
          key: const ValueKey<String>('box'),
          width: 10,
          height: 10,
          padding: const EdgeInsets.all(20),
          child: box('c', 40, 20),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(rectOf(tester, 'box').size, const Size(10, 10));
      expect(rectOf(tester, 'c').size, Size.zero);
    });

    testWidgets('intrinsic sizes include the insets and respect the fixed and min sizes', (WidgetTester tester) async {
      Future<RenderKkBox> pump(KkBox box) async {
        await pumpRaw(tester, box);
        return tester.renderObject<RenderKkBox>(find.byType(KkBox));
      }

      RenderKkBox r = await pump(
        KkBox(padding: const EdgeInsets.all(8), edges: KkEdges.line(_red), child: box('c', 40, 20)),
      );
      expect(r.getMaxIntrinsicWidth(double.infinity), 58);
      expect(r.getMinIntrinsicWidth(double.infinity), 58);
      expect(r.getMaxIntrinsicHeight(double.infinity), 38);
      expect(r.getMinIntrinsicHeight(double.infinity), 38);
      r = await pump(KkBox(width: 100, height: 70, child: box('c', 40, 20)));
      expect(r.getMaxIntrinsicWidth(double.infinity), 100);
      expect(r.getMinIntrinsicHeight(double.infinity), 70);
      r = await pump(KkBox(minWidth: 80, minHeight: 60, child: box('c', 40, 20)));
      expect(r.getMaxIntrinsicWidth(double.infinity), 80);
      expect(r.getMaxIntrinsicHeight(double.infinity), 60);
      r = await pump(KkBox(maxWidth: 30, maxHeight: 15, child: box('c', 40, 20)));
      expect(r.getMaxIntrinsicWidth(double.infinity), 30);
      expect(r.getMaxIntrinsicHeight(double.infinity), 15);
      r = await pump(const KkBox(padding: EdgeInsets.all(3)));
      expect(r.getMaxIntrinsicWidth(double.infinity), 6);
    });

    testWidgets('dry layout equals real layout', (WidgetTester tester) async {
      for (final Alignment? alignment in <Alignment?>[null, Alignment.center]) {
        for (final BoxConstraints c in <BoxConstraints>[
          const BoxConstraints(),
          const BoxConstraints(maxWidth: 300, maxHeight: 200),
          BoxConstraints.tight(const Size(120, 80)),
          const BoxConstraints(minWidth: 90, maxWidth: 400),
        ]) {
          await pumpRaw(
            tester,
            UnconstrainedBox(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: c,
                child: KkBox(
                  key: const ValueKey<String>('box'),
                  padding: const EdgeInsets.all(8),
                  edges: KkEdges.line(_red, width: 2),
                  alignment: alignment,
                  child: box('c', 40, 20),
                ),
              ),
            ),
          );
          final RenderKkBox r = tester.renderObject<RenderKkBox>(byId('box'));
          expect(r.getDryLayout(r.constraints), r.size, reason: '$alignment under $c');
        }
      }
    });

    testWidgets('the child baseline is offset by the top inset', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        KkRow(
          cross: KkCrossAlign.baseline,
          shrinkWrap: true,
          children: <Widget>[
            KkBox(
              key: const ValueKey<String>('box'),
              padding: const EdgeInsets.only(top: 10, bottom: 3),
              edges: const KkEdges(top: KkSide(_red, width: 2)),
              child: Text('A', key: const ValueKey<String>('in'), style: testStyle(20)),
            ),
            Text('B', key: const ValueKey<String>('out'), style: testStyle(20)),
          ],
        ),
      );
      // Same font size, so the inner text top must equal the outer text top.
      expect(rectOf(tester, 'in').top, rectOf(tester, 'out').top);
      expect(rectOf(tester, 'in').top, 12);
      final RenderKkBox r = tester.renderObject<RenderKkBox>(byId('box'));
      final double textBase = baselineOf(tester.renderObject<RenderBox>(byId('in')))!;
      expect(baselineOf(r), closeTo(12 + textBase, 1e-6));
    });

    testWidgets('a decoration that keeps the border widths repaints without a new layout', (
      WidgetTester tester,
    ) async {
      Widget build(Color fill, double border) => KkBox(
        key: const ValueKey<String>('box'),
        width: 50,
        height: 50,
        decoration: KkDecoration(fill: fill, edges: KkEdges.line(_red, width: border)),
        child: box('c'),
      );
      await pumpRaw(tester, build(_red, 1));
      final RenderKkBox r = tester.renderObject<RenderKkBox>(byId('box'));
      await pumpRaw(tester, build(_blue, 1));
      expect(rectOf(tester, 'c').size, const Size(48, 48));
      expect(r.decoration!.fill, _blue);
      await pumpRaw(tester, build(_blue, 5));
      expect(rectOf(tester, 'c').size, const Size(40, 40));
    });

    test('fill or edges together with a decoration is an error', () {
      expect(() => KkBox(fill: _red, decoration: const KkDecoration()), throwsAssertionError);
      expect(() => KkBox(edges: KkEdges.none, decoration: const KkDecoration()), throwsAssertionError);
    });
  });

  group('KkBox hit testing', () {
    Future<List<String>> tapOver(WidgetTester tester, Widget over) async {
      final List<String> log = <String>[];
      await pumpRaw(
        tester,
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => log.add('behind')),
              ),
              Positioned.fill(child: over),
            ],
          ),
        ),
      );
      await tester.tapAt(const Offset(50, 50));
      return log;
    }

    testWidgets('a filled box blocks what is behind it', (WidgetTester tester) async {
      expect(await tapOver(tester, const KkBox(fill: _red)), isEmpty);
    });

    testWidgets('an empty box lets taps through', (WidgetTester tester) async {
      expect(await tapOver(tester, const KkBox()), <String>['behind']);
      expect(await tapOver(tester, KkBox(edges: KkEdges.line(_red))), <String>['behind']);
      expect(await tapOver(tester, const KkBox(fill: Color(0x00FF0000))), <String>['behind']);
    });

    testWidgets('opaque overrides the default', (WidgetTester tester) async {
      expect(await tapOver(tester, const KkBox(opaque: true)), isEmpty);
      expect(await tapOver(tester, const KkBox(fill: _red, opaque: false)), <String>['behind']);
    });

    testWidgets('the child is hit at its padded position', (WidgetTester tester) async {
      int taps = 0;
      await pumpRaw(
        tester,
        KkBox(
          padding: const EdgeInsets.all(30),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      );
      await tester.tapAt(const Offset(10, 10));
      expect(taps, 0);
      await tester.tapAt(const Offset(50, 50));
      expect(taps, 1);
    });
  });

  group('KkBox paint', () {
    testWidgets('clips an oversized child and still composites repaint boundaries', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        const KkBox(
          key: ValueKey<String>('box'),
          width: 50,
          height: 50,
          clip: true,
          fill: _red,
          child: OverflowBox(
            maxWidth: 100,
            maxHeight: 100,
            alignment: Alignment.topLeft,
            child: RepaintBoundary(child: ColoredBox(color: _blue, child: SizedBox(width: 100, height: 100))),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final RenderKkBox r = tester.renderObject<RenderKkBox>(byId('box'));
      expect(r.describeApproximatePaintClip(r.child!), const Rect.fromLTWH(0, 0, 50, 50));
      expect(r.clip, isTrue);
    });

    testWidgets('paints a full decoration in both orders without error', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        KkBox(
          width: 120,
          height: 64,
          decoration: KkDecoration(
            fill: _red,
            pattern: const KkPattern.grid(color: _blue),
            edges: KkEdges.line(_blue, dashed: true),
            brackets: const KkBracketSpec(color: _blue),
            glow: const KkGlow(color: _blue),
            overlay: const KkPattern.scanlines(color: _blue),
          ),
          child: box('c'),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('KkSurface', () {
    testWidgets('is exactly as large as its child', (WidgetTester tester) async {
      await pumpRaw(
        tester,
        KkSurface(key: const ValueKey<String>('s'), shape: const KkShape.plate(10), fill: _red, child: box('c', 80, 36)),
      );
      expect(rectOf(tester, 's').size, const Size(80, 36));
    });

    Future<List<String>> tapAt(WidgetTester tester, KkShape shape, Offset point) async {
      final List<String> log = <String>[];
      await pumpRaw(
        tester,
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => log.add('behind')),
              ),
              Positioned.fill(
                child: KkSurface(
                  shape: shape,
                  fill: _red,
                  child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => log.add('surface')),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.tapAt(point);
      return log;
    }

    testWidgets('a hexagon takes taps in its body and not in its cut corners', (WidgetTester tester) async {
      expect(await tapAt(tester, const KkShape.hex(), const Offset(50, 50)), <String>['surface']);
      expect(await tapAt(tester, const KkShape.hex(), const Offset(3, 3)), <String>['behind']);
      expect(await tapAt(tester, const KkShape.hex(), const Offset(97, 97)), <String>['behind']);
    });

    testWidgets('a chamfered plate does not take taps in the cut', (WidgetTester tester) async {
      const KkShape plate = KkShape.plate(30);
      expect(await tapAt(tester, plate, const Offset(4, 4)), <String>['behind']);
      expect(await tapAt(tester, plate, const Offset(96, 96)), <String>['behind']);
      expect(await tapAt(tester, plate, const Offset(96, 4)), <String>['surface']);
      expect(await tapAt(tester, plate, const Offset(50, 50)), <String>['surface']);
    });

    testWidgets('a slant and an arrow follow their outline', (WidgetTester tester) async {
      expect(await tapAt(tester, const KkShape.slant(40), const Offset(95, 95)), <String>['behind']);
      expect(await tapAt(tester, const KkShape.slant(40), const Offset(95, 5)), <String>['surface']);
      expect(await tapAt(tester, const KkShape.arrow(head: 30), const Offset(5, 50)), <String>['behind']);
      expect(await tapAt(tester, const KkShape.arrow(head: 30), const Offset(95, 50)), <String>['surface']);
      expect(await tapAt(tester, const KkShape.arrow(head: 30), const Offset(97, 4)), <String>['behind']);
      expect(await tapAt(tester, const KkShape.arrow(head: 30, notch: false), const Offset(5, 50)), <String>['surface']);
    });

    testWidgets('a surface with no fill and no edge still passes taps to its child', (WidgetTester tester) async {
      int taps = 0;
      await pumpRaw(
        tester,
        KkSurface(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      );
      await tester.tapAt(const Offset(20, 20));
      expect(taps, 1);
    });

    testWidgets('paints every shape, clipped or not, with a glow', (WidgetTester tester) async {
      for (final KkShape shape in const <KkShape>[
        KkShape.rect(),
        KkShape.chamfer(tl: 6, tr: 4, br: 10, bl: 2),
        KkShape.plate(10),
        KkShape.slant(14),
        KkShape.hex(),
        KkShape.arrow(),
        KkShape.arrow(notch: false),
      ]) {
        for (final bool clip in <bool>[false, true]) {
          await pumpRaw(
            tester,
            KkSurface(
              key: const ValueKey<String>('s'),
              shape: shape,
              fill: _red,
              edge: _blue,
              edgeWidth: 2,
              glow: const KkGlow(color: _blue),
              clip: clip,
              child: const RepaintBoundary(child: SizedBox(width: 60, height: 40)),
            ),
          );
          expect(tester.takeException(), isNull);
        }
      }
      final RenderKkSurface r = tester.renderObject<RenderKkSurface>(byId('s'));
      expect(r.edgeWidth, 2);
      expect(r.clip, isTrue);
    });
  });
}
