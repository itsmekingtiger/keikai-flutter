import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

// ignore: avoid_relative_lib_imports
import '../../example/lib/screens/catalogue_screen.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/screens/situation_screen.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/screens/systems_screen.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/sheets/charts_sheet.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/sheets/controls_sheet.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/sheets/diagram_sheet.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/sheets/foundation_sheet.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/sheets/hud_sheet.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/sheets/inputs_sheet.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/sheets/layout_sheet.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/sheets/shell_sheet.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/sheets/table_sheet.dart';
import 'app_harness.dart';

final List<(String, Finder)> _families = <(String, Finder)>[
  ('FOUNDATION', find.byType(FoundationSheet)),
  ('LAYOUT', find.byType(LayoutSheet)),
  ('CONTROLS', find.byType(ControlsSheet)),
  ('INPUTS', find.byType(InputsSheet)),
  ('SHELL', find.byType(ShellSheet)),
  ('INSTRUMENTS', find.byType(HudSheet)),
  ('CHARTS', find.byType(ChartsSheet)),
  ('DIAGRAMS', find.byType(DiagramSheet)),
  ('TABLE', find.byType(TableSheet)),
];

/// The catalogue's own tab bar (the shell sheet shows tab bars of its own).
Finder _tabs() => find.byType(KkTabs).first;

Finder _tab(String en) => find.descendant(of: _tabs(), matching: find.text(en));

void main() {
  setUpAll(loadKkFonts);

  forEveryWindow('the catalogue pins its head and scrolls the sheet both ways', '/catalogue', (
    WidgetTester tester,
    Rig rig,
    Size size,
  ) async {
    expect(find.byType(CatalogueScreen), findsOneWidget);
    expect(find.byType(FoundationSheet), findsOneWidget);
    // The sheet keeps its 1440px whatever the window.
    expect(tester.getSize(find.byType(FoundationSheet)).width, 1440);
    final Rect tabs = tester.getRect(_tabs());
    // Scrolling the sheet down and sideways leaves the tabs where they are.
    final Offset before = tester.getTopLeft(find.byType(FoundationSheet));
    // A point of the sheet that is on screen: just under the tabs.
    final Offset grip = Offset(tabs.center.dx, tabs.bottom + 80);
    await tester.dragFrom(grip, const Offset(0, -200));
    await tester.pump();
    await tester.dragFrom(grip, const Offset(-120, 0));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.getRect(_tabs()), tabs);
    final Offset after = tester.getTopLeft(find.byType(FoundationSheet));
    expect(after.dy, lessThan(before.dy - 100));
    // Sideways only where the sheet is wider than the window.
    if (size.width < 1500) {
      expect(after.dx, lessThan(before.dx - 50));
    } else {
      expect(after.dx, before.dx);
    }
  });

  testWidgets('every family opens from its tab, from its own top-left corner', (WidgetTester tester) async {
    await pumpApp(tester, route: '/catalogue', size: const Size(1280, 800));
    for (final (String en, Finder sheet) in _families.reversed) {
      await tester.ensureVisible(_tab(en));
      await tester.pumpAndSettle();
      await tester.tap(_tab(en));
      await tester.pumpAndSettle();
      expect(sheet, findsOneWidget, reason: en);
      for (final (String other, Finder otherSheet) in _families) {
        if (other != en) expect(otherSheet, findsNothing, reason: '$other while $en is shown');
      }
      // The last crumb names the family on show.
      expect(find.descendant(of: find.byType(KkBreadcrumbs).first, matching: find.text(en)), findsOneWidget);
      expectClean(tester, en);
      // A newly chosen sheet starts at its own corner, whatever the last one was scrolled to.
      final Rect tabs = tester.getRect(_tabs());
      expect(tester.getTopLeft(sheet), Offset(tabs.left, tabs.bottom + 12), reason: '$en starts at its corner');
      await tester.dragFrom(Offset(tabs.center.dx, tabs.bottom + 80), const Offset(-150, -250));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(sheet).dy, lessThan(tabs.bottom - 100));
    }
  });

  testWidgets('in a short window the title and the tabs scroll away with the sheet', (WidgetTester tester) async {
    // Tall enough: the tabs stay where they are while the sheet scrolls.
    await pumpApp(tester, size: const Size(1280, 800), route: '/catalogue');
    await tester.pumpAndSettle();
    final double pinned = tester.getRect(_tabs()).top;
    await tester.dragFrom(const Offset(700, 600), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(_tabs()).top, pinned);
    await tester.pumpWidget(const KkBox());

    // A phone held sideways: there is no room to pin them, the page scrolls as one.
    await pumpApp(tester, size: const Size(667, 375), route: '/catalogue');
    await tester.pumpAndSettle();
    expectClean(tester, 'short catalogue');
    final double before = tester.getRect(_tabs()).top;
    // (A finger has to move 20px before a drag begins: the page follows the rest.)
    await tester.dragFrom(const Offset(400, 250), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(tester.getRect(_tabs()).top, moreOrLessEquals(before - (200 - kDragSlopDefault), epsilon: 0.01));
    // The sheet is on screen now, and still scrolls sideways.
    final Rect sheet = tester.getRect(find.byType(FoundationSheet));
    expect(sheet.top, lessThan(375 - 32));
    await tester.dragFrom(const Offset(400, 250), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(FoundationSheet)).left,
      moreOrLessEquals(sheet.left - (300 - kDragSlopDefault), epsilon: 0.01),
    );
    // A tab still opens its family from the top-left corner.
    await tester.dragFrom(const Offset(400, 200), const Offset(0, 200));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: _tabs(), matching: find.text('LAYOUT')));
    await tester.pumpAndSettle();
    expect(find.byType(LayoutSheet), findsOneWidget);
    expect(tester.getRect(find.byType(LayoutSheet)).left, greaterThanOrEqualTo(72));
    expectClean(tester, 'short catalogue after scrolling');
  });

  testWidgets('the arrows step through the families and stop at the ends', (WidgetTester tester) async {
    await pumpApp(tester, route: '/catalogue');
    expect(tester.widget<KkIconButton>(iconButton('Previous family')).onPressed, isNull);
    for (int i = 1; i < _families.length; i++) {
      await tester.tap(iconButton('Next family'));
      await tester.pumpAndSettle();
      expect(_families[i].$2, findsOneWidget);
      expect(tester.widget<KkTabs>(_tabs()).index, i);
    }
    expect(tester.widget<KkIconButton>(iconButton('Next family')).onPressed, isNull);
    await tester.tap(iconButton('Previous family'));
    await tester.pumpAndSettle();
    expect(find.byType(DiagramSheet), findsOneWidget);
    expectClean(tester, 'arrows');
  });

  testWidgets('the trail leads back: catalogue, then the board', (WidgetTester tester) async {
    await pumpApp(tester, route: '/catalogue');
    await tester.tap(_tab('CHARTS'));
    await tester.pumpAndSettle();
    final Finder crumbs = find.byType(KkBreadcrumbs).first;
    await tester.tap(find.descendant(of: crumbs, matching: find.text('BOARD')));
    await tester.pumpAndSettle();
    expect(find.byType(SituationScreen), findsOneWidget);
    expect(find.byType(CatalogueScreen), findsNothing);
    expectClean(tester, 'trail');
  });

  testWidgets('a sheet that shows a menu open does not keep the keyboard or the scroll position', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, route: '/catalogue', size: const Size(1280, 800));
    await tester.tap(_tab('INPUTS'));
    await tester.pumpAndSettle();
    final Rect tabs = tester.getRect(_tabs());
    expect(tester.getTopLeft(find.byType(InputsSheet)), Offset(tabs.left, tabs.bottom + 12));
    // The open menus of the sheet stay on the sheet: none floats over the command bar or the toolbar.
    for (final Element menu in find.byWidgetPredicate((Widget w) => w is KkMenu).evaluate()) {
      final Rect r = tester.getRect(find.byWidget(menu.widget));
      expect(r.top, greaterThan(tabs.bottom), reason: 'a menu at $r');
    }
    // The console keys still work: 2 goes to the systems screen.
    await pressKey(tester, LogicalKeyboardKey.digit2, '2');
    await tester.pumpAndSettle();
    expect(find.byType(CatalogueScreen), findsNothing);
    expect(find.byType(SystemsScreen), findsOneWidget);
    expectClean(tester, 'inputs sheet');
  });

  testWidgets('the sheets come alive with motion on', (WidgetTester tester) async {
    await pumpApp(tester, route: '/catalogue', size: const Size(1280, 800), motion: true);
    for (final String en in <String>['INSTRUMENTS', 'CHARTS', 'DIAGRAMS', 'SHELL']) {
      await tester.ensureVisible(_tab(en));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(_tab(en));
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expectClean(tester, en);
    }
  });
}
