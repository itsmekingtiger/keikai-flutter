import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';
import 'package:keikai/src/layout/layout.dart';

import 'layout_util.dart';

/// A screen with every region, each a keyed box of a known size.
Widget _screen({
  bool side = true,
  bool nav = true,
  bool bars = true,
  EdgeInsets? padding,
  bool scrollBody = true,
  double bodyHeight = 100,
  double navHeight = 0,
  ScrollController? bodyController,
}) {
  return KkScreen(
    commandBar: bars ? box('cmd', null, 48) : null,
    nav: nav
        ? Builder(
            builder: (BuildContext context) {
              final bool bar = KkScreenScope.of(context).navIsBar;
              return bar ? box('nav', null, 64) : box('nav', 72, navHeight == 0 ? null : navHeight);
            },
          )
        : null,
    body: box('body', null, scrollBody ? bodyHeight : null),
    side: side
        ? Builder(
            builder: (BuildContext context) =>
                KkScreenScope.of(context).sideIsStacked ? box('side', null, 100) : box('side', 200),
          )
        : null,
    footer: bars ? box('foot', null, 32) : null,
    padding: padding,
    scrollBody: scrollBody,
    bodyController: bodyController,
  );
}

Future<void> _pump(WidgetTester tester, Widget screen, Size size) => pumpRaw(tester, screen, size: size, loose: false);

void main() {
  group('arrangement', () {
    testWidgets('840 and wider: nav | body | side between the bars', (WidgetTester tester) async {
      await _pump(tester, _screen(), const Size(1000, 600));
      expect(rectOf(tester, 'cmd'), const Rect.fromLTWH(0, 0, 1000, 48));
      expect(rectOf(tester, 'foot'), const Rect.fromLTWH(0, 568, 1000, 32));
      expect(rectOf(tester, 'nav'), const Rect.fromLTWH(0, 48, 72, 520));
      expect(rectOf(tester, 'side'), const Rect.fromLTWH(800, 48, 200, 520));
      // The body is padded by the 16px grid margin.
      expect(rectOf(tester, 'body'), const Rect.fromLTWH(88, 64, 696, 100));
    });

    testWidgets('exactly 840 is expanded, 839 is medium', (WidgetTester tester) async {
      await _pump(tester, _screen(), const Size(840, 600));
      expect(rectOf(tester, 'side').left, 640);
      await _pump(tester, _screen(), const Size(839, 600));
      expect(rectOf(tester, 'side').left, 72);
    });

    testWidgets('600 to 839: the side region sits under the body, nav keeps the full height', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _screen(), const Size(700, 600));
      expect(rectOf(tester, 'nav'), const Rect.fromLTWH(0, 48, 72, 520));
      expect(rectOf(tester, 'side'), const Rect.fromLTWH(72, 468, 628, 100));
      expect(rectOf(tester, 'body'), const Rect.fromLTWH(88, 64, 596, 100));
      // The body region ends where the side region begins.
      final RenderBox region = tester.renderObject<RenderBox>(find.byType(KkScroll).first);
      expect(region.size, const Size(628, 420));
    });

    testWidgets('below 600: one column, nav as a bar above the footer', (WidgetTester tester) async {
      await _pump(tester, _screen(), const Size(400, 600));
      expect(rectOf(tester, 'cmd'), const Rect.fromLTWH(0, 0, 400, 48));
      expect(rectOf(tester, 'side'), const Rect.fromLTWH(0, 404, 400, 100));
      expect(rectOf(tester, 'nav'), const Rect.fromLTWH(0, 504, 400, 64));
      expect(rectOf(tester, 'foot'), const Rect.fromLTWH(0, 568, 400, 32));
      // Compact margin is 8.
      expect(rectOf(tester, 'body'), const Rect.fromLTWH(8, 56, 384, 100));
      await _pump(tester, _screen(), const Size(599, 600));
      expect(rectOf(tester, 'nav').height, 64);
      await _pump(tester, _screen(), const Size(600, 600));
      expect(rectOf(tester, 'nav').width, 72);
    });

    testWidgets('wall displays use a 32px margin', (WidgetTester tester) async {
      await _pump(tester, _screen(side: false), const Size(2560, 1000));
      expect(rectOf(tester, 'body').left, 72 + 32);
      expect(rectOf(tester, 'body').top, 48 + 32);
      await _pump(tester, _screen(side: false), const Size(2559, 1000));
      expect(rectOf(tester, 'body').left, 72 + 16);
    });

    testWidgets('a body alone fills the screen', (WidgetTester tester) async {
      await _pump(tester, _screen(side: false, nav: false, bars: false, scrollBody: false), const Size(1000, 600));
      expect(rectOf(tester, 'body'), const Rect.fromLTWH(16, 16, 968, 568));
      await _pump(tester, _screen(side: false, nav: false, bars: false, scrollBody: false), const Size(300, 200));
      expect(rectOf(tester, 'body'), const Rect.fromLTWH(8, 8, 284, 184));
    });

    testWidgets('padding can be overridden', (WidgetTester tester) async {
      await _pump(
        tester,
        _screen(side: false, padding: const EdgeInsets.fromLTRB(1, 2, 3, 4), scrollBody: false),
        const Size(1000, 600),
      );
      expect(rectOf(tester, 'body'), const Rect.fromLTRB(73, 50, 997, 564));
      await _pump(tester, _screen(side: false, padding: EdgeInsets.zero, scrollBody: false), const Size(1000, 600));
      expect(rectOf(tester, 'body'), const Rect.fromLTWH(72, 48, 928, 520));
    });

    testWidgets('bars taller than the screen leave nothing for the body and do not throw', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _screen(), const Size(1000, 60));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KkScreen)), const Size(1000, 60));
    });

    testWidgets('a zero-size screen does not throw', (WidgetTester tester) async {
      await pumpRaw(tester, SizedBox(width: 0, height: 0, child: _screen()));
      expect(tester.takeException(), isNull);
    });
  });

  group('scrolling', () {
    testWidgets('the body scrolls when its content is taller', (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await _pump(tester, _screen(bodyHeight: 2000, bodyController: controller), const Size(1000, 600));
      expect(controller.position.maxScrollExtent, 2000 + 32 - 520);
      controller.jumpTo(300);
      await tester.pump();
      expect(rectOf(tester, 'body').top, 64 - 300);
      // The bars stay where they are.
      expect(rectOf(tester, 'cmd').top, 0);
    });

    testWidgets('a short body does not scroll', (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await _pump(tester, _screen(bodyController: controller), const Size(1000, 600));
      expect(controller.position.maxScrollExtent, 0);
    });

    testWidgets('scrollBody false hands the body the exact space', (WidgetTester tester) async {
      await _pump(tester, _screen(scrollBody: false), const Size(1000, 600));
      expect(rectOf(tester, 'body'), const Rect.fromLTWH(88, 64, 696, 488));
      expect(find.byType(KkScroll), findsNWidgets(2));
    });

    testWidgets('a nav taller than its space scrolls; a short one is stretched to fill', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _screen(navHeight: 1500), const Size(1000, 600));
      expect(rectOf(tester, 'nav').height, 1500);
      final ScrollableState nav = tester.state<ScrollableState>(
        find.ancestor(of: byId('nav'), matching: find.byType(Scrollable)).first,
      );
      expect(nav.position.maxScrollExtent, 1500 - 520);
      nav.position.jumpTo(100);
      await tester.pump();
      expect(rectOf(tester, 'nav').top, 48 - 100);
      await _pump(tester, _screen(), const Size(1000, 600));
      expect(rectOf(tester, 'nav').height, 520);
    });
  });

  group('scope', () {
    testWidgets('descendants read the mode and the window class', (WidgetTester tester) async {
      late KkScreenData data;
      late KkWindowClass scoped;
      Widget probe() => KkScreen(
        body: Builder(
          builder: (BuildContext context) {
            data = KkScreenScope.of(context);
            scoped = KkWindowScope.of(context);
            return const SizedBox.shrink();
          },
        ),
      );
      const List<(double, KkScreenMode, KkWindowClass)> cases = <(double, KkScreenMode, KkWindowClass)>[
        (400, KkScreenMode.compact, KkWindowClass.compact),
        (700, KkScreenMode.medium, KkWindowClass.medium),
        (900, KkScreenMode.expanded, KkWindowClass.expanded),
        (1300, KkScreenMode.expanded, KkWindowClass.large),
        (1700, KkScreenMode.expanded, KkWindowClass.xlarge),
        (2600, KkScreenMode.expanded, KkWindowClass.wall),
      ];
      for (final (double width, KkScreenMode mode, KkWindowClass cls) in cases) {
        await _pump(tester, probe(), Size(width, 600));
        expect(data.mode, mode, reason: '$width');
        expect(data.windowClass, cls, reason: '$width');
        expect(data.width, width);
        expect(scoped, cls);
        expect(data.navIsBar, mode == KkScreenMode.compact);
        expect(data.sideIsStacked, mode != KkScreenMode.expanded);
      }
    });

    testWidgets('the screen follows its own width, not the window', (WidgetTester tester) async {
      late KkScreenData data;
      await pumpRaw(
        tester,
        SizedBox(
          width: 500,
          height: 400,
          child: KkScreen(
            body: Builder(
              builder: (BuildContext context) {
                data = KkScreenScope.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        size: const Size(1400, 900),
      );
      expect(data.mode, KkScreenMode.compact);
      expect(data.width, 500);
    });

    testWidgets('maybeOf is null outside a screen and of asserts', (WidgetTester tester) async {
      late BuildContext outside;
      await pumpRaw(
        tester,
        Builder(
          builder: (BuildContext context) {
            outside = context;
            return const SizedBox.shrink();
          },
        ),
      );
      expect(KkScreenScope.maybeOf(outside), isNull);
      expect(() => KkScreenScope.of(outside), throwsAssertionError);
    });

    test('data equality', () {
      const KkScreenData a = KkScreenData(windowClass: KkWindowClass.large, mode: KkScreenMode.expanded, width: 1300);
      const KkScreenData b = KkScreenData(windowClass: KkWindowClass.large, mode: KkScreenMode.expanded, width: 1300);
      const KkScreenData c = KkScreenData(windowClass: KkWindowClass.large, mode: KkScreenMode.expanded, width: 1301);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
      expect(a.toString(), contains('1300'));
    });
  });

  group('state and input', () {
    testWidgets('regions keep their state when the arrangement changes', (WidgetTester tester) async {
      Widget build() => const KkScreen(
        nav: _Counter(id: 'nav'),
        side: _Counter(id: 'side'),
        body: _Counter(id: 'body'),
      );
      await _pump(tester, build(), const Size(1000, 600));
      for (final String id in <String>['nav', 'side', 'body']) {
        await tester.tap(byId(id));
      }
      await tester.pump();
      expect(find.text('nav 1'), findsOneWidget);
      for (final Size size in const <Size>[Size(700, 600), Size(400, 600), Size(1000, 600)]) {
        await _pump(tester, build(), size);
        expect(find.text('nav 1'), findsOneWidget, reason: '$size');
        expect(find.text('side 1'), findsOneWidget, reason: '$size');
        expect(find.text('body 1'), findsOneWidget, reason: '$size');
      }
    });

    testWidgets('a region can be removed and added without disturbing the others', (WidgetTester tester) async {
      Widget build(bool side) => KkScreen(
        nav: const _Counter(id: 'nav'),
        side: side ? const _Counter(id: 'side') : null,
        body: const _Counter(id: 'body'),
      );
      await _pump(tester, build(true), const Size(1000, 600));
      await tester.tap(byId('nav'));
      await tester.tap(byId('body'));
      await tester.pump();
      await _pump(tester, build(false), const Size(1000, 600));
      expect(find.text('nav 1'), findsOneWidget);
      expect(find.text('body 1'), findsOneWidget);
      expect(byId('side'), findsNothing);
      await _pump(tester, build(true), const Size(1000, 600));
      expect(find.text('side 0'), findsOneWidget);
      expect(find.text('nav 1'), findsOneWidget);
    });

    testWidgets('each region takes its own taps', (WidgetTester tester) async {
      final List<String> log = <String>[];
      Widget target(String id, {double? width, double? height}) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => log.add(id),
        child: SizedBox(width: width, height: height),
      );
      await _pump(
        tester,
        KkScreen(
          commandBar: target('cmd', height: 48),
          nav: target('nav', width: 72),
          body: target('body', height: 400),
          side: target('side', width: 200),
          footer: target('foot', height: 32),
        ),
        const Size(1000, 600),
      );
      await tester.tapAt(const Offset(500, 20));
      await tester.tapAt(const Offset(30, 300));
      await tester.tapAt(const Offset(400, 300));
      await tester.tapAt(const Offset(900, 300));
      await tester.tapAt(const Offset(500, 590));
      expect(log, <String>['cmd', 'nav', 'body', 'side', 'foot']);
    });
  });

  group('edges', () {
    testWidgets('without a height limit the screen is as tall as its content', (WidgetTester tester) async {
      for (final Size size in const <Size>[Size(1000, 600), Size(700, 600), Size(400, 600)]) {
        await pumpRaw(
          tester,
          SingleChildScrollView(child: _screen(bodyHeight: 300)),
          size: size,
          loose: false,
        );
        expect(tester.takeException(), isNull, reason: '$size');
        final Size s = tester.getSize(find.byType(KkScreen));
        expect(s.width, size.width);
        expect(rectOf(tester, 'cmd').top, 0);
        expect(rectOf(tester, 'foot').bottom, s.height);
        expect(rectOf(tester, 'body').height, 300);
      }
      // Expanded: the nav is stretched to the height of the tallest region.
      await pumpRaw(
        tester,
        SingleChildScrollView(child: _screen(bodyHeight: 300)),
        size: const Size(1000, 600),
        loose: false,
      );
      expect(rectOf(tester, 'nav').height, 300 + 32);
      expect(tester.getSize(find.byType(KkScreen)).height, 48 + 332 + 32);
    });

    testWidgets('safeArea keeps clear of system intrusions and the keyboard', (WidgetTester tester) async {
      Widget build({required bool safeArea}) => MediaQuery(
        data: const MediaQueryData(
          size: Size(1000, 600),
          padding: EdgeInsets.only(top: 24, bottom: 10),
          viewInsets: EdgeInsets.only(bottom: 200),
        ),
        child: KkScreen(
          commandBar: box('cmd', null, 48),
          body: Builder(
            builder: (BuildContext context) {
              // The intrusions are consumed for the regions.
              expect(MediaQuery.paddingOf(context), safeArea ? EdgeInsets.zero : isNot(EdgeInsets.zero));
              return box('body', null, 10);
            },
          ),
          footer: box('foot', null, 32),
          safeArea: safeArea,
        ),
      );
      await _pump(tester, build(safeArea: true), const Size(1000, 600));
      expect(rectOf(tester, 'cmd').top, 24);
      expect(rectOf(tester, 'foot').bottom, 400);
      await _pump(tester, build(safeArea: false), const Size(1000, 600));
      expect(rectOf(tester, 'cmd').top, 0);
      expect(rectOf(tester, 'foot').bottom, 600);
    });

    testWidgets('paints the grid ground by default and nothing extra when told so', (WidgetTester tester) async {
      await _pump(tester, _screen(), const Size(1000, 600));
      KkBackdrop backdrop = tester.widget<KkBackdrop>(find.byType(KkBackdrop));
      expect(backdrop.kind, KkBackdropKind.grid);
      await _pump(tester, KkScreen(body: box('body'), backdrop: KkBackdropKind.none), const Size(1000, 600));
      backdrop = tester.widget<KkBackdrop>(find.byType(KkBackdrop));
      expect(backdrop.kind, KkBackdropKind.none);
    });

    testWidgets('dry layout of the skeleton is the space it is given', (WidgetTester tester) async {
      await _pump(tester, _screen(), const Size(1000, 600));
      final RenderKkScreen r = tester.renderObject<RenderKkScreen>(
        find.byWidgetPredicate((Widget w) => w is MultiChildRenderObjectWidget && w.runtimeType.toString() == '_KkScreenLayout'),
      );
      expect(r.getDryLayout(r.constraints), r.size);
      expect(r.mode, KkScreenMode.expanded);
      expect(r.describeApproximatePaintClip(r.firstChild!), const Rect.fromLTWH(0, 0, 1000, 600));
      expect(r.toStringDeep(), contains('mode: expanded'));
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter({required this.id});

  final String id;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey<String>(widget.id),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _count++),
      child: SizedBox(
        width: 100,
        height: 40,
        child: Text('${widget.id} $_count', style: testStyle(10)),
      ),
    );
  }
}
