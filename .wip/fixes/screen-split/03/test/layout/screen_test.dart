import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';
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
    testChecked('840 and wider: nav | body | side between the bars', (WidgetTester tester) async {
      await _pump(tester, _screen(), const Size(1000, 600));
      expect(rectOf(tester, 'cmd'), const Rect.fromLTWH(0, 0, 1000, 48));
      expect(rectOf(tester, 'foot'), const Rect.fromLTWH(0, 568, 1000, 32));
      expect(rectOf(tester, 'nav'), const Rect.fromLTWH(0, 48, 72, 520));
      expect(rectOf(tester, 'side'), const Rect.fromLTWH(800, 48, 200, 520));
      // The body is padded by the 16px grid margin.
      expect(rectOf(tester, 'body'), const Rect.fromLTWH(88, 64, 696, 100));
    });

    testChecked('exactly 840 is expanded, 839 is medium', (WidgetTester tester) async {
      await _pump(tester, _screen(), const Size(840, 600));
      expect(rectOf(tester, 'side').left, 640);
      await _pump(tester, _screen(), const Size(839, 600));
      expect(rectOf(tester, 'side').left, 72);
    });

    testChecked('600 to 839: the side region sits under the body, nav keeps the full height', (
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

    testChecked('below 600: one column, nav as a bar above the footer', (WidgetTester tester) async {
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

    testChecked('wall displays use a 32px margin', (WidgetTester tester) async {
      await _pump(tester, _screen(side: false), const Size(2560, 1000));
      expect(rectOf(tester, 'body').left, 72 + 32);
      expect(rectOf(tester, 'body').top, 48 + 32);
      await _pump(tester, _screen(side: false), const Size(2559, 1000));
      expect(rectOf(tester, 'body').left, 72 + 16);
    });

    testChecked('a body alone fills the screen', (WidgetTester tester) async {
      await _pump(tester, _screen(side: false, nav: false, bars: false, scrollBody: false), const Size(1000, 600));
      expect(rectOf(tester, 'body'), const Rect.fromLTWH(16, 16, 968, 568));
      await _pump(tester, _screen(side: false, nav: false, bars: false, scrollBody: false), const Size(300, 200));
      expect(rectOf(tester, 'body'), const Rect.fromLTWH(8, 8, 284, 184));
    });

    testChecked('padding can be overridden', (WidgetTester tester) async {
      await _pump(
        tester,
        _screen(side: false, padding: const EdgeInsets.fromLTRB(1, 2, 3, 4), scrollBody: false),
        const Size(1000, 600),
      );
      expect(rectOf(tester, 'body'), const Rect.fromLTRB(73, 50, 997, 564));
      await _pump(tester, _screen(side: false, padding: EdgeInsets.zero, scrollBody: false), const Size(1000, 600));
      expect(rectOf(tester, 'body'), const Rect.fromLTWH(72, 48, 928, 520));
    });

    testChecked('bars taller than the screen leave nothing for the body and do not throw', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _screen(), const Size(1000, 60));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KkScreen)), const Size(1000, 60));
    });

    testChecked('a zero-size screen does not throw', (WidgetTester tester) async {
      await pumpRaw(tester, SizedBox(width: 0, height: 0, child: _screen()));
      expect(tester.takeException(), isNull);
    });
  });

  group('scrolling', () {
    testChecked('the body scrolls when its content is taller', (WidgetTester tester) async {
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

    testChecked('a short body does not scroll', (WidgetTester tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await _pump(tester, _screen(bodyController: controller), const Size(1000, 600));
      expect(controller.position.maxScrollExtent, 0);
    });

    testChecked('scrollBody false hands the body the exact space', (WidgetTester tester) async {
      await _pump(tester, _screen(scrollBody: false), const Size(1000, 600));
      expect(rectOf(tester, 'body'), const Rect.fromLTWH(88, 64, 696, 488));
      expect(find.byType(KkScroll), findsNWidgets(2));
    });

    testChecked('a nav taller than its space scrolls; a short one is stretched to fill', (
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

  group('nav and side that deal with their own height', () {
    setUpAll(loadKkFonts);

    // A sheet with [content] px of content and one action in its foot row.
    KkSheet sheet(double content) => KkSheet(
      cjk: '詳細',
      en: 'detail',
      actions: <Widget>[KkButton(key: const ValueKey<String>('ok'), label: 'ok', onPressed: () {})],
      child: box('content', null, content),
    );

    Widget withSheet(double content) => KkScreen(
      commandBar: box('cmd', null, 48),
      footer: box('foot', null, 32),
      body: box('body', null, 100),
      side: sheet(content),
      scrollSide: false,
    );

    testChecked('scrollSide off: a sheet beside the body keeps head and foot in place and scrolls its body', (
      WidgetTester tester,
    ) async {
      for (final double content in <double>[100, 2000]) {
        await pumpKk(tester, withSheet(content), size: const Size(1200, 700), alignment: null);
        expect(tester.takeException(), isNull, reason: '$content');
        // The sheet is exactly the region; its foot row ends 12px above the edge.
        expect(tester.getRect(find.byType(KkSheet)), const Rect.fromLTRB(800, 48, 1200, 668), reason: '$content');
        expect(rectOf(tester, 'ok').bottom, 668 - 12, reason: '$content');
      }
      // The tall content scrolls inside the sheet; nothing around the sheet does.
      final Finder inside = find.descendant(of: find.byType(KkSheet), matching: find.byType(Scrollable));
      final ScrollableState scrollable = tester.state<ScrollableState>(inside);
      expect(scrollable.position.maxScrollExtent, greaterThan(1000));
      expect(find.ancestor(of: find.byType(KkSheet), matching: find.byType(Scrollable)), findsNothing);
      final double title = tester.getTopLeft(find.text('詳細')).dy;
      scrollable.position.jumpTo(300);
      await tester.pump();
      expect(rectOf(tester, 'content').top, lessThan(48));
      expect(tester.getTopLeft(find.text('詳細')).dy, title);
      expect(rectOf(tester, 'ok').bottom, 668 - 12);
    });

    testChecked('scrollSide off, under the body: a sheet takes its own height, up to all there is', (
      WidgetTester tester,
    ) async {
      for (final double width in <double>[700, 400]) {
        // 44 of head, the content in 16 of padding, 61 of foot row.
        await pumpKk(tester, withSheet(100), size: Size(width, 700), alignment: null);
        expect(tester.takeException(), isNull, reason: '$width');
        expect(tester.getRect(find.byType(KkSheet)), Rect.fromLTRB(0, 668 - 237, width, 668), reason: '$width');
        expect(rectOf(tester, 'ok').bottom, 668 - 12, reason: '$width');
        // Too much for the space: the sheet stops at the command bar, the foot
        // row stays and the body scrolls.
        await pumpKk(tester, withSheet(2000), size: Size(width, 700), alignment: null);
        expect(tester.takeException(), isNull, reason: '$width');
        expect(tester.getRect(find.byType(KkSheet)), Rect.fromLTRB(0, 48, width, 668), reason: '$width');
        expect(rectOf(tester, 'ok').bottom, 668 - 12, reason: '$width');
      }
    });

    testChecked('scrollSide off: a list that builds its rows as they come into view has the height it needs', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        KkScreen(
          commandBar: box('cmd', null, 48),
          body: box('body', null, 100),
          side: KkBox(
            width: 300,
            child: KkListView(
              itemCount: 500,
              itemBuilder: (BuildContext context, int index) => box('row $index', null, 40),
            ),
          ),
          scrollSide: false,
        ),
        const Size(1000, 600),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byType(KkListView)), const Rect.fromLTRB(700, 48, 1000, 600));
      expect(byId('row 0'), findsOneWidget);
      expect(byId('row 499'), findsNothing);
    });

    testChecked('scrollNav off: the nav is given exactly the height of its region', (WidgetTester tester) async {
      Widget screen({required bool scrollNav}) => KkScreen(
        commandBar: box('cmd', null, 48),
        footer: box('foot', null, 32),
        nav: KkBox(
          width: 72,
          child: KkColumn(children: <Widget>[box('top', null, 56), const KkSpacer(), box('bottom', null, 56)]),
        ),
        body: box('body', null, 100),
        scrollNav: scrollNav,
      );
      // 840 and wider, and 600 to 839: the spacer has the height to push with.
      for (final double width in <double>[1000, 700]) {
        await _pump(tester, screen(scrollNav: false), Size(width, 600));
        expect(tester.takeException(), isNull, reason: '$width');
        expect(rectOf(tester, 'top'), const Rect.fromLTWH(0, 48, 72, 56), reason: '$width');
        expect(rectOf(tester, 'bottom'), const Rect.fromLTWH(0, 568 - 56, 72, 56), reason: '$width');
        expect(find.ancestor(of: byId('top'), matching: find.byType(KkScroll)), findsNothing, reason: '$width');
      }
      // Left on, the nav scrolls and so has no height to share out.
      await _pump(tester, screen(scrollNav: true), const Size(1000, 600));
      expect(find.ancestor(of: byId('top'), matching: find.byType(KkScroll)), findsOneWidget);
      expect(rectOf(tester, 'bottom').top, 48 + 56);
    });

    testChecked('turning the scrolling of nav and side on and off keeps their state', (WidgetTester tester) async {
      Widget build({required bool scroll}) => KkScreen(
        nav: const _Counter(id: 'nav'),
        side: const _Counter(id: 'side'),
        body: box('body', null, 100),
        scrollNav: scroll,
        scrollSide: scroll,
      );
      for (final Size size in const <Size>[Size(1000, 600), Size(700, 600)]) {
        await _pump(tester, build(scroll: true), size);
        expect(find.byType(KkScroll), findsNWidgets(3), reason: '$size');
        await tester.tap(byId('nav'));
        await tester.tap(byId('side'));
        await tester.pump();
        final String count = size.width == 1000 ? '1' : '2';
        await _pump(tester, build(scroll: false), size);
        expect(find.byType(KkScroll), findsOneWidget, reason: '$size');
        expect(find.text('nav $count'), findsOneWidget, reason: '$size');
        expect(find.text('side $count'), findsOneWidget, reason: '$size');
      }
    });
  });

  group('scope', () {
    testChecked('descendants read the mode and the window class', (WidgetTester tester) async {
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

    testChecked('the screen follows its own width, not the window', (WidgetTester tester) async {
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

    testChecked('maybeOf is null outside a screen and of asserts', (WidgetTester tester) async {
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
    testChecked('regions keep their state when the arrangement changes', (WidgetTester tester) async {
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

    testChecked('a region can be removed and added without disturbing the others', (WidgetTester tester) async {
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

    testChecked('each region takes its own taps', (WidgetTester tester) async {
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
    testChecked('without a height limit the screen is as tall as its content', (WidgetTester tester) async {
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

    testChecked('without a height limit the screen grows with a region that had been stretched', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<double> height = ValueNotifier<double>(100);
      addTearDown(height.dispose);
      // A box that is as tall as [height] says.
      Widget growing(String id, double? width) => ValueListenableBuilder<double>(
        valueListenable: height,
        builder: (BuildContext context, double value, Widget? child) => box(id, width, value),
      );
      // The regions that are not the tallest are stretched to the one that is.
      // [id] starts as one of those and then outgrows the others.
      Future<void> check(String id, Size size, {Widget? nav, Widget? side, required Widget body}) async {
        height.value = 100;
        await pumpRaw(
          tester,
          SingleChildScrollView(
            child: KkScreen(
              padding: EdgeInsets.zero,
              commandBar: box('cmd', null, 48),
              nav: nav,
              body: body,
              side: side,
              footer: box('foot', null, 32),
            ),
          ),
          size: size,
          loose: false,
        );
        expect(tester.getSize(find.byType(KkScreen)).height, 48 + 500 + 32, reason: '$id at $size');
        expect(rectOf(tester, id).height, 500, reason: '$id at $size');
        height.value = 800;
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$id at $size');
        expect(rectOf(tester, id).height, 800, reason: '$id at $size');
        expect(tester.getSize(find.byType(KkScreen)).height, 48 + 800 + 32, reason: '$id at $size');
        expect(rectOf(tester, 'foot').bottom, 48 + 800 + 32, reason: '$id at $size');
      }

      const Size expanded = Size(1000, 600);
      await check('body', expanded, nav: box('nav', 72, 500), body: growing('body', null));
      await check('nav', expanded, nav: growing('nav', 72), body: box('body', null, 500));
      await check('side', expanded, side: growing('side', 200), body: box('body', null, 500));
      // 600 to 839: only the nav is stretched, to the body.
      await check('nav', const Size(700, 600), nav: growing('nav', 72), body: box('body', null, 500));
    });

    testChecked('nav and side stay where they are in the tree while a screen without a height limit is laid out', (
      WidgetTester tester,
    ) async {
      final ValueNotifier<double> height = ValueNotifier<double>(300);
      addTearDown(height.dispose);
      final List<String> log = <String>[];
      for (final Size size in const <Size>[Size(1000, 600), Size(700, 600)]) {
        await pumpRaw(
          tester,
          SingleChildScrollView(
            child: KkScreen(
              nav: _Witness(id: 'nav', log: log),
              side: _Witness(id: 'side', log: log),
              body: ValueListenableBuilder<double>(
                valueListenable: height,
                builder: (BuildContext context, double value, Widget? child) => box('body', null, value),
              ),
            ),
          ),
          size: size,
          loose: false,
        );
        log.clear();
        // Every frame lays the screen out again, with the nav and the side
        // stretched to the body.
        for (int i = 0; i < 3; i++) {
          height.value += 10;
          await tester.pump();
        }
        expect(tester.takeException(), isNull, reason: '$size');
        expect(log, isEmpty, reason: '$size');
      }
    });

    testChecked('with a least height and no limit the regions fill the height the screen takes', (
      WidgetTester tester,
    ) async {
      // A page that is at least as tall as the window and scrolls when its
      // content is taller.
      Widget page(Widget screen) => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints window) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: window.maxHeight),
            child: screen,
          ),
        ),
      );
      Future<void> pump(Size size, {double bodyHeight = 100}) => pumpRaw(
        tester,
        page(_screen(padding: EdgeInsets.zero, bodyHeight: bodyHeight)),
        size: size,
        loose: false,
      );

      // 840 and wider: nav, body and side all reach the footer.
      await pump(const Size(1000, 600));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KkScreen)), const Size(1000, 600));
      expect(rectOf(tester, 'foot'), const Rect.fromLTWH(0, 568, 1000, 32));
      expect(rectOf(tester, 'nav'), const Rect.fromLTWH(0, 48, 72, 520));
      expect(rectOf(tester, 'body'), const Rect.fromLTWH(72, 48, 728, 520));
      expect(rectOf(tester, 'side'), const Rect.fromLTWH(800, 48, 200, 520));

      // 600 to 839: the nav reaches the footer, the body takes what the side leaves.
      await pump(const Size(700, 600));
      expect(tester.getSize(find.byType(KkScreen)), const Size(700, 600));
      expect(rectOf(tester, 'foot'), const Rect.fromLTWH(0, 568, 700, 32));
      expect(rectOf(tester, 'nav'), const Rect.fromLTWH(0, 48, 72, 520));
      expect(rectOf(tester, 'body'), const Rect.fromLTWH(72, 48, 628, 420));
      expect(rectOf(tester, 'side'), const Rect.fromLTWH(72, 468, 628, 100));

      // Below 600: the body takes the extra; side and nav bar sit on the footer.
      await pump(const Size(400, 600));
      expect(tester.getSize(find.byType(KkScreen)), const Size(400, 600));
      expect(rectOf(tester, 'foot'), const Rect.fromLTWH(0, 568, 400, 32));
      expect(rectOf(tester, 'body'), const Rect.fromLTWH(0, 48, 400, 356));
      expect(rectOf(tester, 'side'), const Rect.fromLTWH(0, 404, 400, 100));
      expect(rectOf(tester, 'nav'), const Rect.fromLTWH(0, 504, 400, 64));

      // Content taller than the least height: the screen is as tall as that.
      for (final (Size size, double height) in const <(Size, double)>[
        (Size(1000, 600), 48 + 900 + 32),
        (Size(700, 600), 48 + 900 + 100 + 32),
        (Size(400, 600), 48 + 900 + 100 + 64 + 32),
      ]) {
        await pump(size, bodyHeight: 900);
        expect(tester.takeException(), isNull, reason: '$size');
        expect(tester.getSize(find.byType(KkScreen)).height, height, reason: '$size');
        expect(rectOf(tester, 'body').height, 900, reason: '$size');
        expect(rectOf(tester, 'foot').bottom, height, reason: '$size');
      }
    });

    testChecked('without a height limit a nav taller than body and side gives the body the rest', (
      WidgetTester tester,
    ) async {
      // 600 to 839, nav 500 tall: the side sits on the footer, and the body
      // fills what is above it.
      await pumpRaw(
        tester,
        SingleChildScrollView(child: _screen(padding: EdgeInsets.zero, navHeight: 500)),
        size: const Size(700, 600),
        loose: false,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KkScreen)).height, 48 + 500 + 32);
      expect(rectOf(tester, 'nav'), const Rect.fromLTWH(0, 48, 72, 500));
      expect(rectOf(tester, 'side'), const Rect.fromLTWH(72, 448, 628, 100));
      expect(rectOf(tester, 'body'), const Rect.fromLTWH(72, 48, 628, 400));
    });

    testChecked('without a height limit a body that needs no stretching is laid out once', (WidgetTester tester) async {
      // The body is as tall as the screen less the side: 0.1 + 0.2 - 0.2, which
      // in floating point is a little more than 0.1. That must not count as
      // room to stretch into.
      final List<BoxConstraints> seen = <BoxConstraints>[];
      Widget screen() => KkScreen(
        padding: EdgeInsets.zero,
        body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            seen.add(constraints);
            return const SizedBox(height: 0.1);
          },
        ),
        side: const SizedBox(height: 0.2),
      );
      for (final Size size in const <Size>[Size(700, 600), Size(400, 600)]) {
        seen.clear();
        await pumpRaw(tester, SingleChildScrollView(child: screen()), size: size, loose: false);
        expect(tester.takeException(), isNull, reason: '$size');
        expect(seen, <BoxConstraints>[BoxConstraints(minWidth: size.width, maxWidth: size.width)], reason: '$size');
        expect(tester.getSize(find.byType(KkScreen)).height, 0.1 + 0.2, reason: '$size');
      }
    });

    testChecked('safeArea keeps clear of system intrusions and the keyboard', (WidgetTester tester) async {
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
              // The intrusions are consumed for the regions: neither the
              // padding nor the keyboard is counted a second time inside.
              expect(MediaQuery.paddingOf(context), safeArea ? EdgeInsets.zero : isNot(EdgeInsets.zero));
              expect(MediaQuery.viewInsetsOf(context).bottom, safeArea ? 0 : 200);
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

    testChecked('without the keyboard the bottom padding counts; a nested screen adds nothing', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        MediaQuery(
          data: const MediaQueryData(size: Size(1000, 600), padding: EdgeInsets.fromLTRB(4, 24, 6, 10)),
          child: KkScreen(
            scrollBody: false,
            padding: EdgeInsets.zero,
            body: KkScreen(commandBar: box('cmd', null, 48), body: box('body'), footer: box('foot', null, 32)),
          ),
        ),
        const Size(1000, 600),
      );
      expect(rectOf(tester, 'cmd'), const Rect.fromLTWH(4, 24, 990, 48));
      expect(rectOf(tester, 'foot').bottom, 590);
    });

    testChecked('a keyboard sliding in moves the footer up and keeps every region as it was', (
      WidgetTester tester,
    ) async {
      Widget build(double keyboard) => MediaQuery(
        data: MediaQueryData(size: const Size(400, 600), viewInsets: EdgeInsets.only(bottom: keyboard)),
        child: const KkScreen(
          commandBar: _Counter(id: 'cmd'),
          body: _Counter(id: 'body'),
          footer: _Counter(id: 'foot'),
        ),
      );
      await _pump(tester, build(0), const Size(400, 600));
      for (final String id in <String>['cmd', 'body', 'foot']) {
        await tester.tap(byId(id));
      }
      await tester.pump();
      expect(rectOf(tester, 'foot').bottom, 600);
      await _pump(tester, build(250), const Size(400, 600));
      expect(rectOf(tester, 'foot').bottom, 350);
      for (final String id in <String>['cmd', 'body', 'foot']) {
        expect(find.text('$id 1'), findsOneWidget, reason: id);
      }
      await _pump(tester, build(0), const Size(400, 600));
      expect(rectOf(tester, 'foot').bottom, 600);
      expect(find.text('cmd 1'), findsOneWidget);
    });

    testChecked('with no width limit the screen takes the window width', (WidgetTester tester) async {
      KkScreenData? seen;
      await pumpRaw(
        tester,
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: KkScreen(
            commandBar: box('cmd', null, 48),
            body: Builder(
              builder: (BuildContext context) {
                seen = KkScreenScope.of(context);
                return box('body', null, 10);
              },
            ),
          ),
        ),
        size: const Size(700, 400),
        loose: false,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KkScreen)), const Size(700, 400));
      expect(seen!.width, 700);
      expect(seen!.mode, KkScreenMode.medium);
      expect(rectOf(tester, 'cmd'), const Rect.fromLTWH(0, 0, 700, 48));
    });

    testChecked('paints the grid ground by default and nothing extra when told so', (WidgetTester tester) async {
      await _pump(tester, _screen(), const Size(1000, 600));
      KkBackdrop backdrop = tester.widget<KkBackdrop>(find.byType(KkBackdrop));
      expect(backdrop.kind, KkBackdropKind.grid);
      await _pump(tester, KkScreen(body: box('body'), backdrop: KkBackdropKind.none), const Size(1000, 600));
      backdrop = tester.widget<KkBackdrop>(find.byType(KkBackdrop));
      expect(backdrop.kind, KkBackdropKind.none);
    });

    testChecked('dry layout of the skeleton is the space it is given', (WidgetTester tester) async {
      await _pump(tester, _screen(), const Size(1000, 600));
      final RenderKkScreen r = tester.renderObject<RenderKkScreen>(_layout);
      expect(r.getDryLayout(r.constraints), r.size);
      expect(r.mode, KkScreenMode.expanded);
      expect(r.fallbackWidth, 0);
      expect(r.describeApproximatePaintClip(r.firstChild!), const Rect.fromLTWH(0, 0, 1000, 600));
      expect(r.toStringDeep(), contains('mode: expanded'));
    });

    testChecked('dry layout without a height limit is the height of the regions, in every mode', (
      WidgetTester tester,
    ) async {
      // The render object alone, with plain boxes for regions.
      Widget raw(KkScreenMode mode) => UnconstrainedBox(
        alignment: Alignment.topLeft,
        constrainedAxis: Axis.horizontal,
        child: _RawScreen(
          mode: mode,
          children: <Widget>[
            _Region(slot: KkScreenSlot.body, child: box('body', null, 300)),
            _Region(slot: KkScreenSlot.side, child: box('side', 200, 120)),
            _Region(slot: KkScreenSlot.nav, child: box('nav', 72, 64)),
            _Region(slot: KkScreenSlot.footer, child: box('foot', null, 32)),
            _Region(slot: KkScreenSlot.commandBar, child: box('cmd', null, 48)),
          ],
        ),
      );
      const Map<KkScreenMode, double> heights = <KkScreenMode, double>{
        // Bars 80; the tallest of nav 64, body 300, side 120.
        KkScreenMode.expanded: 380,
        // Bars 80; body 300 over side 120.
        KkScreenMode.medium: 500,
        // Bars 80; body 300, side 120, nav 64 in one column.
        KkScreenMode.compact: 564,
      };
      for (final MapEntry<KkScreenMode, double> e in heights.entries) {
        await pumpRaw(tester, raw(e.key), size: const Size(1000, 600), loose: false);
        expect(tester.takeException(), isNull, reason: '${e.key}');
        final RenderKkScreen r = tester.renderObject<RenderKkScreen>(find.byType(_RawScreen));
        expect(r.size, Size(1000, e.value), reason: '${e.key}');
        expect(r.getDryLayout(r.constraints), r.size, reason: '${e.key}');
        // A screen has no baseline, and says so when asked dry.
        expect(r.getDryBaseline(r.constraints, TextBaseline.alphabetic), isNull, reason: '${e.key}');
        expect(rectOf(tester, 'foot').bottom, e.value, reason: '${e.key}');
      }
      // Expanded: nav and side are stretched to the tallest region.
      await pumpRaw(tester, raw(KkScreenMode.expanded), size: const Size(1000, 600), loose: false);
      expect(rectOf(tester, 'nav'), const Rect.fromLTWH(0, 48, 72, 300));
      expect(rectOf(tester, 'side'), const Rect.fromLTWH(800, 48, 200, 300));
      expect(rectOf(tester, 'body'), const Rect.fromLTWH(72, 48, 728, 300));
    });

    testChecked('the render object alone: no width limit means the fallback width', (WidgetTester tester) async {
      Widget raw(double fallback) => UnconstrainedBox(
        alignment: Alignment.topLeft,
        child: _RawScreen(
          mode: KkScreenMode.compact,
          fallbackWidth: fallback,
          children: <Widget>[
            _Region(slot: KkScreenSlot.body, child: box('body', null, 100)),
          ],
        ),
      );
      await pumpRaw(tester, raw(320), size: const Size(1000, 600), loose: false);
      expect(tester.getSize(find.byType(_RawScreen)), const Size(320, 100));
      await pumpRaw(tester, raw(480), size: const Size(1000, 600), loose: false);
      expect(tester.getSize(find.byType(_RawScreen)), const Size(480, 100));
      final RenderKkScreen r = tester.renderObject<RenderKkScreen>(find.byType(_RawScreen));
      expect(r.getDryLayout(r.constraints), const Size(480, 100));
      expect(r.toStringDeep(), contains('fallbackWidth: 480'));
      // None given: nothing to go by.
      await pumpRaw(tester, raw(0), size: const Size(1000, 600), loose: false);
      expect(tester.getSize(find.byType(_RawScreen)), const Size(0, 100));
      expect(tester.takeException(), isNull);
    });
  });
}

/// The private layout widget inside a [KkScreen].
Finder get _layout => find.byWidgetPredicate(
  (Widget w) => w is MultiChildRenderObjectWidget && w.runtimeType.toString() == '_KkScreenLayout',
);

/// A [RenderKkScreen] with nothing around it.
class _RawScreen extends MultiChildRenderObjectWidget {
  const _RawScreen({required this.mode, this.fallbackWidth = 0, super.children});

  final KkScreenMode mode;
  final double fallbackWidth;

  @override
  RenderKkScreen createRenderObject(BuildContext context) => RenderKkScreen(mode: mode, fallbackWidth: fallbackWidth);

  @override
  void updateRenderObject(BuildContext context, RenderKkScreen renderObject) {
    renderObject
      ..mode = mode
      ..fallbackWidth = fallbackWidth;
  }
}

class _Region extends ParentDataWidget<KkScreenParentData> {
  const _Region({required this.slot, required super.child});

  final KkScreenSlot slot;

  @override
  void applyParentData(RenderObject renderObject) {
    final KkScreenParentData pd = renderObject.parentData! as KkScreenParentData;
    if (pd.slot != slot) {
      pd.slot = slot;
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _RawScreen;
}

/// A 100 by 40 box that writes to [log] when it is built, taken out of the
/// tree or put back into it.
class _Witness extends StatefulWidget {
  const _Witness({required this.id, required this.log});

  final String id;
  final List<String> log;

  @override
  State<_Witness> createState() => _WitnessState();
}

class _WitnessState extends State<_Witness> {
  @override
  void deactivate() {
    widget.log.add('${widget.id} deactivate');
    super.deactivate();
  }

  @override
  void activate() {
    widget.log.add('${widget.id} activate');
    super.activate();
  }

  @override
  Widget build(BuildContext context) {
    widget.log.add('${widget.id} build');
    return const SizedBox(width: 100, height: 40);
  }
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
