import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

const Key _child = ValueKey<String>('popup-child');
const Color _white = Color(0xFFFFFFFF);

Future<void> _pumpLayout(
  WidgetTester tester, {
  required Rect anchor,
  KkPopupSide side = KkPopupSide.below,
  KkPopupAlign align = KkPopupAlign.start,
  Size child = const Size(100, 40),
  bool flip = true,
  bool matchWidth = false,
  bool minAnchorWidth = false,
  double minWidth = 0,
  double gap = 4,
  Color? stem,
  Size screen = const Size(400, 300),
  bool looseWidth = false,
}) async {
  await pumpKk(
    tester,
    KkPopupLayout(
      anchor: anchor,
      side: side,
      align: align,
      gap: gap,
      flip: flip,
      matchWidth: matchWidth,
      minAnchorWidth: minAnchorWidth,
      minWidth: minWidth,
      stem: stem,
      child: KkBox(
        key: _child,
        width: looseWidth ? null : child.width,
        minWidth: looseWidth ? child.width : 0,
        height: child.height,
        fill: _white,
      ),
    ),
    size: screen,
    alignment: null,
  );
}

void main() {
  group('KkPopupLayout', () {
    testWidgets('below, start: left edges together, gap under the anchor', (WidgetTester tester) async {
      await _pumpLayout(tester, anchor: const Rect.fromLTWH(50, 60, 80, 30));
      expect(tester.getRect(find.byKey(_child)), const Rect.fromLTWH(50, 94, 100, 40));
      expect(tester.renderObject<RenderKkPopupLayout>(find.byType(KkPopupLayout)).resolvedSide, KkPopupSide.below);
    });

    testWidgets('above, center', (WidgetTester tester) async {
      await _pumpLayout(
        tester,
        anchor: const Rect.fromLTWH(150, 120, 60, 30),
        side: KkPopupSide.above,
        align: KkPopupAlign.center,
        gap: 8,
      );
      expect(tester.getRect(find.byKey(_child)), const Rect.fromLTWH(130, 72, 100, 40));
    });

    testWidgets('left, end and right, start', (WidgetTester tester) async {
      await _pumpLayout(
        tester,
        anchor: const Rect.fromLTWH(200, 100, 40, 60),
        side: KkPopupSide.left,
        align: KkPopupAlign.end,
      );
      expect(tester.getRect(find.byKey(_child)), const Rect.fromLTWH(96, 120, 100, 40));

      await _pumpLayout(tester, anchor: const Rect.fromLTWH(200, 100, 40, 60), side: KkPopupSide.right);
      expect(tester.getRect(find.byKey(_child)), const Rect.fromLTWH(244, 100, 100, 40));
    });

    testWidgets('flips above when there is no room below', (WidgetTester tester) async {
      await _pumpLayout(tester, anchor: const Rect.fromLTWH(50, 250, 80, 30));
      expect(tester.getRect(find.byKey(_child)), const Rect.fromLTWH(50, 206, 100, 40));
      expect(tester.renderObject<RenderKkPopupLayout>(find.byType(KkPopupLayout)).resolvedSide, KkPopupSide.above);
    });

    testWidgets('does not flip when flip is off; it is kept on screen instead', (WidgetTester tester) async {
      await _pumpLayout(tester, anchor: const Rect.fromLTWH(50, 250, 80, 30), flip: false);
      final Rect r = tester.getRect(find.byKey(_child));
      expect(tester.renderObject<RenderKkPopupLayout>(find.byType(KkPopupLayout)).resolvedSide, KkPopupSide.below);
      expect(r.bottom, lessThanOrEqualTo(296));
    });

    testWidgets('flips from right to left and from above to below', (WidgetTester tester) async {
      await _pumpLayout(tester, anchor: const Rect.fromLTWH(340, 100, 40, 40), side: KkPopupSide.right);
      expect(tester.getRect(find.byKey(_child)).right, 336);

      await _pumpLayout(tester, anchor: const Rect.fromLTWH(100, 10, 40, 20), side: KkPopupSide.above);
      expect(tester.getRect(find.byKey(_child)).top, 34);
    });

    testWidgets('is shifted to stay 4px inside the screen', (WidgetTester tester) async {
      await _pumpLayout(tester, anchor: const Rect.fromLTWH(360, 60, 30, 30));
      expect(tester.getRect(find.byKey(_child)), const Rect.fromLTWH(296, 94, 100, 40));

      await _pumpLayout(tester, anchor: const Rect.fromLTWH(2, 60, 20, 30), align: KkPopupAlign.center);
      expect(tester.getRect(find.byKey(_child)).left, 4);
    });

    testWidgets('with room on neither side it takes the roomier one and what room there is', (
      WidgetTester tester,
    ) async {
      await _pumpLayout(
        tester,
        anchor: const Rect.fromLTWH(50, 100, 80, 30),
        child: const Size(100, 1000),
        screen: const Size(400, 400),
      );
      // Below: 400 - 4 - 134 = 262. Above: 96 - 4 = 92.
      final Rect r = tester.getRect(find.byKey(_child));
      expect(r.top, 134);
      expect(r.height, 262);
    });

    testWidgets('matchWidth makes the child exactly as wide as the anchor', (WidgetTester tester) async {
      await _pumpLayout(
        tester,
        anchor: const Rect.fromLTWH(50, 60, 180, 30),
        matchWidth: true,
        looseWidth: true,
        child: const Size(20, 40),
      );
      expect(tester.getRect(find.byKey(_child)), const Rect.fromLTWH(50, 94, 180, 40));
    });

    testWidgets('minAnchorWidth and minWidth set a floor', (WidgetTester tester) async {
      await _pumpLayout(
        tester,
        anchor: const Rect.fromLTWH(50, 60, 180, 30),
        minAnchorWidth: true,
        looseWidth: true,
        child: const Size(20, 40),
      );
      expect(tester.getSize(find.byKey(_child)).width, 180);

      await _pumpLayout(
        tester,
        anchor: const Rect.fromLTWH(50, 60, 20, 30),
        minWidth: 232,
        looseWidth: true,
        child: const Size(20, 40),
      );
      expect(tester.getSize(find.byKey(_child)).width, 232);
    });

    testWidgets('paints a stem and survives a tiny screen and an anchor off screen', (WidgetTester tester) async {
      await _pumpLayout(
        tester,
        anchor: const Rect.fromLTWH(150, 120, 60, 30),
        side: KkPopupSide.above,
        align: KkPopupAlign.center,
        gap: 8,
        stem: _white,
      );
      expect(tester.takeException(), isNull);
      await _pumpLayout(
        tester,
        anchor: const Rect.fromLTWH(-500, -500, 10, 10),
        stem: _white,
        screen: const Size(6, 6),
      );
      expect(tester.takeException(), isNull);
      await _pumpLayout(tester, anchor: Rect.zero, side: KkPopupSide.left, stem: _white, child: Size.zero);
      expect(tester.takeException(), isNull);
    });

    testWidgets('only the child takes pointer events', (WidgetTester tester) async {
      int behind = 0;
      int inside = 0;
      await pumpKk(
        tester,
        KkLayers(
          expand: true,
          children: <Widget>[
            GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => behind++),
            KkPopupLayout(
              anchor: const Rect.fromLTWH(50, 60, 80, 30),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => inside++,
                child: const KkBox(key: _child, width: 100, height: 40),
              ),
            ),
          ],
        ),
        size: const Size(400, 300),
        alignment: null,
      );
      await tester.tapAt(const Offset(300, 250));
      expect((behind, inside), (1, 0));
      await tester.tapAt(tester.getCenter(find.byKey(_child)));
      expect((behind, inside), (1, 1));
    });
  });

  group('KkPopup', () {
    testWidgets('controller opens, closes and toggles; listeners are told', (WidgetTester tester) async {
      final KkPopupController controller = KkPopupController();
      addTearDown(controller.dispose);
      int notified = 0;
      controller.addListener(() => notified++);
      await pumpKk(
        tester,
        KkPopup(
          controller: controller,
          popupBuilder: (BuildContext context) => const KkBox(key: _child, width: 100, height: 40, fill: _white),
          child: const KkBox(width: 80, height: 30, fill: _white),
        ),
        padding: const EdgeInsets.all(50),
      );
      expect(find.byKey(_child), findsNothing);
      controller.open();
      controller.open();
      await tester.pump();
      expect(controller.isOpen, isTrue);
      expect(notified, 1);
      expect(tester.getRect(find.byKey(_child)), const Rect.fromLTWH(50, 84, 100, 40));
      controller.toggle();
      await tester.pump();
      expect(find.byKey(_child), findsNothing);
      expect(notified, 2);
      controller.close();
      expect(notified, 2);
    });

    testWidgets('a press outside closes it; a press on the anchor or the popup does not', (WidgetTester tester) async {
      final KkPopupController controller = KkPopupController()..open();
      addTearDown(controller.dispose);
      await pumpKk(
        tester,
        KkPopup(
          controller: controller,
          popupBuilder: (BuildContext context) => const KkBox(key: _child, width: 100, height: 40, fill: _white),
          child: const KkBox(width: 80, height: 30, fill: _white),
        ),
        padding: const EdgeInsets.all(50),
      );
      expect(find.byKey(_child), findsOneWidget);
      await tester.tapAt(const Offset(60, 60));
      await tester.pump();
      expect(controller.isOpen, isTrue);
      await tester.tapAt(tester.getCenter(find.byKey(_child)));
      await tester.pump();
      expect(controller.isOpen, isTrue);
      await tester.tapAt(const Offset(600, 500));
      await tester.pump();
      expect(controller.isOpen, isFalse);
      expect(find.byKey(_child), findsNothing);
    });

    testWidgets('closeOnTapOutside: false keeps it open', (WidgetTester tester) async {
      final KkPopupController controller = KkPopupController()..open();
      addTearDown(controller.dispose);
      await pumpKk(
        tester,
        KkPopup(
          controller: controller,
          closeOnTapOutside: false,
          popupBuilder: (BuildContext context) => const KkBox(key: _child, width: 100, height: 40, fill: _white),
          child: const KkBox(width: 80, height: 30, fill: _white),
        ),
        padding: const EdgeInsets.all(50),
      );
      await tester.tapAt(const Offset(600, 500));
      await tester.pump();
      expect(controller.isOpen, isTrue);
    });

    testWidgets('follows its anchor when the page scrolls', (WidgetTester tester) async {
      final KkPopupController controller = KkPopupController()..open();
      final ScrollController scroll = ScrollController();
      addTearDown(controller.dispose);
      addTearDown(scroll.dispose);
      await pumpKk(
        tester,
        KkScroll(
          controller: scroll,
          child: KkBox(
            height: 2000,
            alignment: Alignment.topLeft,
            padding: const EdgeInsets.only(top: 200, left: 40),
            child: KkPopup(
              controller: controller,
              popupBuilder: (BuildContext context) => const KkBox(key: _child, width: 100, height: 40, fill: _white),
              child: const KkBox(width: 80, height: 30, fill: _white),
            ),
          ),
        ),
        alignment: null,
      );
      expect(tester.getTopLeft(find.byKey(_child)), const Offset(40, 234));
      scroll.jumpTo(120);
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(_child)), const Offset(40, 114));
    });

    testWidgets('is positioned in the very first frame', (WidgetTester tester) async {
      final KkPopupController controller = KkPopupController()..open();
      addTearDown(controller.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        kkHarness(
          KkPopup(
            controller: controller,
            side: KkPopupSide.right,
            popupBuilder: (BuildContext context) => const KkBox(key: _child, width: 100, height: 40, fill: _white),
            child: const KkBox(width: 80, height: 30, fill: _white),
          ),
          padding: const EdgeInsets.all(50),
        ),
      );
      expect(tester.getRect(find.byKey(_child)), const Rect.fromLTWH(134, 50, 100, 40));
    });

    testWidgets('mouse wheel over the popup does not throw', (WidgetTester tester) async {
      final KkPopupController controller = KkPopupController()..open();
      addTearDown(controller.dispose);
      await pumpKk(
        tester,
        KkPopup(
          controller: controller,
          popupBuilder: (BuildContext context) => const KkBox(key: _child, width: 100, height: 40, fill: _white),
          child: const KkBox(width: 80, height: 30, fill: _white),
        ),
        padding: const EdgeInsets.all(50),
      );
      final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(tester.getCenter(find.byKey(_child))));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 20)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('an open popup asks for no frames: pumpAndSettle returns', (WidgetTester tester) async {
      final KkPopupController controller = KkPopupController();
      addTearDown(controller.dispose);
      await pumpKk(
        tester,
        KkPopup(
          controller: controller,
          popupBuilder: (BuildContext context) => const KkBox(key: _child, width: 100, height: 40, fill: _white),
          child: const KkBox(width: 60, height: 30, fill: _white),
        ),
        padding: const EdgeInsets.all(40),
      );
      controller.open();
      await tester.pumpAndSettle();
      expect(find.byKey(_child), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      controller.close();
      await tester.pumpAndSettle();
      expect(find.byKey(_child), findsNothing);
    });

    testWidgets('a widget may open and close it while it is being rebuilt', (WidgetTester tester) async {
      final KkPopupController controller = KkPopupController();
      addTearDown(controller.dispose);
      final List<bool> told = <bool>[];
      controller.addListener(() => told.add(controller.isOpen));
      await pumpKk(tester, _Driven(open: false, controller: controller), padding: const EdgeInsets.all(40));
      expect(find.byKey(_child), findsNothing);

      // Opened from didUpdateWidget: allowed, and there one frame later.
      await pumpKk(tester, _Driven(open: true, controller: controller), padding: const EdgeInsets.all(40));
      expect(tester.takeException(), isNull);
      expect(controller.isOpen, isTrue);
      expect(told, <bool>[true]);
      await tester.pump();
      expect(find.byKey(_child), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(_child)), const Offset(40, 74));

      // Closed from didUpdateWidget: gone in that very frame.
      await pumpKk(tester, _Driven(open: false, controller: controller), padding: const EdgeInsets.all(40));
      expect(tester.takeException(), isNull);
      expect(find.byKey(_child), findsNothing);
      expect(told, <bool>[true, false]);
      await tester.pump();
      expect(find.byKey(_child), findsNothing);

      // Open, shut and open again inside one build: the last word counts.
      await pumpKk(
        tester,
        _Driven(open: true, controller: controller, flicker: true),
        padding: const EdgeInsets.all(40),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(_child), findsOneWidget);
      // Outside a build it still acts at once.
      controller.close();
      await tester.pump();
      expect(find.byKey(_child), findsNothing);
    });

    testWidgets('a controller disposed with a change still pending does not throw', (WidgetTester tester) async {
      final KkPopupController controller = KkPopupController();
      await pumpKk(tester, _Driven(open: false, controller: controller));
      await pumpKk(tester, _Driven(open: true, controller: controller));
      await pumpKk(tester, const KkBox(width: 10, height: 10));
      controller.dispose();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}

/// Opens or closes its popup from `didUpdateWidget`, as a control does when
/// its owner turns it off while it is open.
class _Driven extends StatefulWidget {
  const _Driven({required this.open, required this.controller, this.flicker = false});

  final bool open;
  final KkPopupController controller;

  /// Go the other way and back within the same build.
  final bool flicker;

  @override
  State<_Driven> createState() => _DrivenState();
}

class _DrivenState extends State<_Driven> {
  @override
  void didUpdateWidget(_Driven oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flicker) {
      widget.controller
        ..open()
        ..close();
    }
    if (widget.open) {
      widget.controller.open();
    } else {
      widget.controller.close();
    }
  }

  @override
  Widget build(BuildContext context) => KkPopup(
    controller: widget.controller,
    popupBuilder: (BuildContext context) => const KkBox(key: _child, width: 100, height: 40, fill: _white),
    child: const KkBox(width: 60, height: 30, fill: _white),
  );
}
