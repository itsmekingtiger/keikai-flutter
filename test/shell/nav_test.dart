import 'package:flutter_test/flutter_test.dart';
import 'package:keikai/keikai.dart';

import '../support/harness.dart';

const List<KkNavItem> _items = <KkNavItem>[
  KkNavItem(icon: KkIcons.grid, label: 'board'),
  KkNavItem(icon: KkIcons.server, label: 'systems', badge: KkBadge(count: 3)),
  KkNavItem(icon: KkIcons.lock, label: 'secure', enabled: false),
  KkNavItem(icon: KkIcons.bell, label: 'alarms'),
];

const List<KkNavSection<String>> _sections = <KkNavSection<String>>[
  KkNavSection<String>(
    cjk: '監視',
    en: 'monitor',
    code: 'NAV-01',
    items: <KkNavDrawerItem<String>>[
      KkNavDrawerItem<String>(value: 'board', icon: KkIcons.grid, cjk: '状況', en: 'situation', meta: '12'),
      KkNavDrawerItem<String>(
        value: 'systems',
        icon: KkIcons.server,
        cjk: '系統',
        en: 'systems',
        meta: '11/12',
        level: KkLevel.nominal,
      ),
    ],
  ),
  KkNavSection<String>(
    cjk: '対処',
    en: 'respond',
    items: <KkNavDrawerItem<String>>[
      KkNavDrawerItem<String>(value: 'alarms', icon: KkIcons.bell, cjk: '警報', en: 'alarms', level: KkLevel.critical),
      KkNavDrawerItem<String>(value: 'lock', icon: KkIcons.lock, cjk: '封鎖', en: 'lockdown', enabled: false),
    ],
  ),
];

Finder _railItem(String label) => find.ancestor(of: find.text(label), matching: find.byType(KkPressable));

String? _focused() => FocusManager.instance.primaryFocus?.debugLabel;

/// Gives [child] the full height of the surface and its own width, the way
/// the nav region of a screen does.
Widget _fullHeight(Widget child) => KkRow(cross: KkCrossAlign.stretch, children: <Widget>[child]);

void main() {
  setUpAll(loadKkFonts);

  group('KkNavRail', () {
    testWidgets('is 72px wide with 56px destinations, 4px apart', (WidgetTester tester) async {
      await pumpKk(
        tester,
        _fullHeight(KkNavRail(items: _items, index: 1, onChanged: (int _) {})),
        size: const Size(400, 500),
        alignment: null,
      );
      expect(tester.getSize(find.byType(KkNavRail)), const Size(72, 500));
      final Rect board = tester.getRect(_railItem('BOARD'));
      final Rect systems = tester.getRect(_railItem('SYSTEMS'));
      // 72 less the 1px line at the right; 8px padding on top.
      expect(board, const Rect.fromLTWH(0, 8, 71, 56));
      expect(systems.top - board.bottom, 4);
      expect(tester.widget<Text>(find.text('BOARD')).style!.fontSize, 10);
    });

    testWidgets('tapping a destination reports its index; disabled ones do not', (WidgetTester tester) async {
      final List<int> log = <int>[];
      await pumpKk(
        tester,
        KkNavRail(items: _items, index: 0, onChanged: log.add),
        size: const Size(400, 500),
      );
      await tester.tap(find.text('ALARMS'));
      await tester.tap(find.text('SECURE'));
      expect(log, <int>[3]);
      const KkColors c = KkColors.standby;
      expect(tester.widget<Text>(find.text('BOARD')).style!.color, c.ink);
      expect(tester.widget<Text>(find.text('ALARMS')).style!.color, c.inkDim);
      expect(tester.widget<Text>(find.text('SECURE')).style!.color, c.inkFaint);
    });

    testWidgets('the current destination has a lit icon and is announced as selected', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(
        tester,
        KkNavRail(items: _items, index: 1, onChanged: (int _) {}),
        size: const Size(400, 500),
      );
      const KkColors c = KkColors.standby;
      Color iconColor(String label) =>
          tester.widget<KkIcon>(find.descendant(of: _railItem(label), matching: find.byType(KkIcon))).color!;
      expect(iconColor('SYSTEMS'), c.signal);
      expect(iconColor('BOARD'), c.inkDim);
      expect(find.bySemanticsLabel('systems'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('systems')),
        isSemantics(label: 'systems', isButton: true, isSelected: true, hasSelectedState: true),
      );
      handle.dispose();
    });

    testWidgets('with onChanged null every destination is disabled', (WidgetTester tester) async {
      await pumpKk(tester, const KkNavRail(items: _items, index: 0), size: const Size(400, 500));
      expect(tester.widget<Text>(find.text('BOARD')).style!.color, KkColors.standby.inkFaint);
      await tester.tap(find.text('ALARMS'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a badge is pinned 6px above and 10px beyond the icon', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkNavRail(items: _items, index: 0, onChanged: (int _) {}),
        size: const Size(400, 500),
      );
      final Rect icon = tester.getRect(find.descendant(of: _railItem('SYSTEMS'), matching: find.byType(KkIcon)));
      final Rect badge = tester.getRect(find.byType(KkBadge));
      expect(icon.size, const Size(16, 16));
      expect(badge.top, icon.top - 6);
      expect(badge.right, icon.right + 10);
    });

    testWidgets('header sits on top, the trailing slot on the bottom edge', (WidgetTester tester) async {
      await pumpKk(
        tester,
        _fullHeight(
          KkNavRail(
            items: _items,
            index: 0,
            onChanged: (int _) {},
            header: const KkBox(key: ValueKey<String>('head'), width: 32, height: 32),
            trailing: const KkBox(key: ValueKey<String>('tail'), width: 32, height: 32),
          ),
        ),
        size: const Size(400, 500),
        alignment: null,
      );
      final Rect head = tester.getRect(find.byKey(const ValueKey<String>('head')));
      final Rect tail = tester.getRect(find.byKey(const ValueKey<String>('tail')));
      expect(head.top, 8 + 4);
      expect(head.center.dx, 35.5);
      expect(tail.bottom, 500 - 8);
      expect(tester.getRect(_railItem('BOARD')).top, head.bottom + 12 + 4);
    });

    testWidgets('Up and Down move the keyboard focus, skipping disabled destinations', (WidgetTester tester) async {
      final List<int> log = <int>[];
      await pumpKk(
        tester,
        KkNavRail(items: _items, index: 0, onChanged: log.add),
        size: const Size(400, 500),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focused(), 'KkNavItem 0');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(_focused(), 'KkNavItem 1');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(_focused(), 'KkNavItem 3');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(_focused(), 'KkNavItem 1');
      // Focus alone selects nothing; Enter does.
      expect(log, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(log, <int>[1]);
    });

    testWidgets('bar form: 64px high, destinations share the width, header hidden', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkNavRail(
          bar: true,
          items: _items,
          index: 3,
          onChanged: (int _) {},
          header: const KkBox(key: ValueKey<String>('head'), width: 32, height: 32),
        ),
        size: const Size(412, 500),
      );
      expect(tester.getSize(find.byType(KkNavRail)), const Size(412, 64));
      expect(find.byKey(const ValueKey<String>('head')), findsNothing);
      final Rect a = tester.getRect(_railItem('BOARD'));
      final Rect b = tester.getRect(_railItem('SYSTEMS'));
      // Four destinations and three 4px gaps across 412px; 64 less the 1px top line.
      expect(a, const Rect.fromLTWH(0, 1, 100, 63));
      expect(b.left, 104);
      expect(b.width, 100);
    });

    testWidgets('inside a KkScreen it is a column at 600px and a bottom bar at 599px', (WidgetTester tester) async {
      Widget screen() => KkScreen(
        nav: KkNavRail(items: _items, index: 0, onChanged: (int _) {}),
        body: const KkBox(height: 100),
      );
      await pumpKk(tester, screen(), size: const Size(600, 500), alignment: null);
      expect(tester.getRect(find.byType(KkNavRail)), const Rect.fromLTWH(0, 0, 72, 500));

      await pumpKk(tester, screen(), size: const Size(599, 500), alignment: null);
      expect(tester.getRect(find.byType(KkNavRail)), const Rect.fromLTWH(0, 500 - 64, 599, 64));
      // In bar form Left and Right move the focus.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final String? first = _focused();
      expect(first, startsWith('KkNavItem'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(_focused(), isNot(first));
    });

    testWidgets('survives no items, long labels and a very short rail', (WidgetTester tester) async {
      await pumpKk(tester, const KkNavRail(items: <KkNavItem>[]), size: const Size(300, 300));
      expect(tester.takeException(), isNull);
      await pumpKk(
        tester,
        KkBox(
          height: 40,
          child: KkNavRail(
            items: const <KkNavItem>[
              KkNavItem(icon: KkIcons.grid, label: 'a label far too long for a rail'),
              KkNavItem(icon: KkIcons.grid, label: 'second'),
            ],
            index: 0,
            onChanged: (int _) {},
          ),
        ),
        size: const Size(300, 300),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.text('A LABEL FAR TOO LONG FOR A RAIL')).width, lessThanOrEqualTo(71));
    });
  });

  group('KkNavDrawer', () {
    testWidgets('is 256px wide with 36px destinations', (WidgetTester tester) async {
      await pumpKk(
        tester,
        _fullHeight(KkNavDrawer<String>(sections: _sections, value: 'systems', onChanged: (String _) {})),
        size: const Size(600, 600),
        alignment: null,
      );
      expect(tester.getSize(find.byType(KkNavDrawer<String>)), const Size(256, 600));
      final Rect item = tester.getRect(find.ancestor(of: find.text('SITUATION'), matching: find.byType(KkPressable)));
      // 256 less the 1px line, less 8px padding on both sides.
      expect(item.size, const Size(239, 36));
      expect(item.left, 8);
      expect(find.text('MONITOR'), findsOneWidget);
      expect(find.text('NAV-01'), findsOneWidget);
      expect(find.text('11/12'), findsOneWidget);
      // A status icon for each destination that has a level.
      expect(find.byType(KkGlyph), findsNWidgets(2));
    });

    testWidgets('tapping reports the value; disabled destinations do not', (WidgetTester tester) async {
      final List<String> log = <String>[];
      await pumpKk(
        tester,
        KkNavDrawer<String>(sections: _sections, value: 'board', onChanged: log.add),
        size: const Size(600, 600),
      );
      await tester.tap(find.text('ALARMS'));
      await tester.tap(find.text('LOCKDOWN'));
      expect(log, <String>['alarms']);
      const KkColors c = KkColors.standby;
      expect(tester.widget<Text>(find.text('封鎖')).style!.color, c.inkFaint);
      expect(tester.widget<Text>(find.text('警報')).style!.color, c.ink);
      expect(tester.widget<Text>(find.text('ALARMS')).style!.color, c.inkDim);
      // The current destination: ink subtitle, signal icon.
      expect(tester.widget<Text>(find.text('SITUATION')).style!.color, c.ink);
      final Finder current = find.ancestor(of: find.text('SITUATION'), matching: find.byType(KkPressable));
      expect(tester.widget<KkIcon>(find.descendant(of: current, matching: find.byType(KkIcon))).color, c.signal);
    });

    testWidgets('the current destination is announced as selected', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpKk(
        tester,
        KkNavDrawer<String>(sections: _sections, value: 'systems', onChanged: (String _) {}),
        size: const Size(600, 600),
      );
      expect(
        tester.getSemantics(find.text('SYSTEMS')),
        isSemantics(isButton: true, isSelected: true, hasSelectedState: true),
      );
      expect(
        tester.getSemantics(find.text('SITUATION')),
        isSemantics(isButton: true, isSelected: false, hasSelectedState: true),
      );
      handle.dispose();
    });

    testWidgets('the foot stays on the bottom edge when there is room', (WidgetTester tester) async {
      await pumpKk(
        tester,
        _fullHeight(
          KkNavDrawer<String>(
            sections: _sections,
            onChanged: (String _) {},
            head: const KkText('HEAD'),
            foot: const KkText('BUILD 0.1.0'),
          ),
        ),
        size: const Size(600, 600),
        alignment: null,
      );
      expect(tester.getBottomLeft(find.text('BUILD 0.1.0')).dy, 600 - 12);
      expect(tester.getTopLeft(find.text('HEAD')).dy, 12);
      final TextStyle foot = tester
          .widget<RichText>(find.descendant(of: find.text('BUILD 0.1.0'), matching: find.byType(RichText)))
          .text
          .style!;
      expect(foot.fontSize, 11);
      expect(foot.color, KkColors.standby.inkDim);
    });

    testWidgets('scrolls when it is taller than its space', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          height: 120,
          child: KkNavDrawer<String>(sections: _sections, onChanged: (String _) {}, foot: const KkText('BUILD 0.1.0')),
        ),
        size: const Size(600, 600),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KkNavDrawer<String>)), const Size(256, 120));
      final double before = tester.getTopLeft(find.text('SITUATION')).dy;
      await tester.drag(find.text('SITUATION'), const Offset(0, -60));
      await tester.pump();
      expect(tester.getTopLeft(find.text('SITUATION')).dy, lessThan(before));
    });

    testWidgets('sizes to its content when the height is free, and tolerates no sections', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkScroll(
          child: KkNavDrawer<String>(sections: _sections, onChanged: (String _) {}),
        ),
        size: const Size(600, 600),
      );
      expect(tester.takeException(), isNull);
      // 12 + (22.6 + 4 + 2×36 + 2×2) + 16 + (same) + 12, roughly.
      expect(tester.getSize(find.byType(KkNavDrawer<String>)).height, closeTo(240, 6));
      await pumpKk(tester, const KkNavDrawer<int>(sections: <KkNavSection<int>>[]), size: const Size(600, 600));
      expect(tester.takeException(), isNull);
    });
  });

  group('KkToolbar', () {
    testWidgets('is 32px high with hints at the left and the status at the right', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkToolbar(
          leading: <Widget>[
            KkToolbarGroup(
              children: <Widget>[
                KkBox(key: ValueKey<String>('a'), width: 24, height: 24),
                KkBox(key: ValueKey<String>('b'), width: 24, height: 24),
              ],
            ),
          ],
          hints: <KkToolbarHint>[
            KkToolbarHint(keys: 'F1', label: 'help'),
            KkToolbarHint(keys: 'ESC', label: 'close'),
          ],
          status: 'LINK OK · 14:02:31Z',
        ),
        size: const Size(900, 300),
      );
      expect(tester.getSize(find.byType(KkToolbar)), const Size(900, 32));
      final Rect a = tester.getRect(find.byKey(const ValueKey<String>('a')));
      final Rect b = tester.getRect(find.byKey(const ValueKey<String>('b')));
      expect(a.left, 8);
      expect(b.left - a.right, 2);
      // Centred in the 30px under the 2px line.
      expect(a.center.dy, 2 + 15);
      expect(find.byType(KkKbd), findsNWidgets(2));
      expect(find.text('HELP'), findsOneWidget);
      expect(tester.getTopLeft(find.byType(KkKbd).first).dx, b.right + 16);
      expect(tester.getTopRight(find.text('LINK OK · 14:02:31Z')).dx, 900 - 8);
      expect(tester.widget<Text>(find.text('LINK OK · 14:02:31Z')).style!.fontSize, 11);
    });

    testWidgets('children replace the slots; a bar that is too narrow is cut, not broken', (WidgetTester tester) async {
      await pumpKk(
        tester,
        const KkBox(
          width: 60,
          child: KkToolbar(
            children: <Widget>[
              KkToolbarHint(keys: 'CTRL+K', label: 'search'),
              KkSpacer(),
              KkToolbarStatus('A STATUS LINE MUCH LONGER THAN THE BAR'),
            ],
          ),
        ),
        size: const Size(900, 300),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(KkToolbar)), const Size(60, 32));
      await pumpKk(tester, const KkToolbar(), size: const Size(900, 300));
      expect(tester.takeException(), isNull);
    });
  });

  group('KkBreadcrumbs', () {
    testWidgets('links go, the last crumb is the current page', (WidgetTester tester) async {
      final List<String> log = <String>[];
      await pumpKk(
        tester,
        KkBreadcrumbs(
          items: <KkCrumb>[
            KkCrumb(code: 'HQ-03', en: 'board', onPressed: () => log.add('board')),
            KkCrumb(cjk: '系統', en: 'systems', onPressed: () => log.add('systems')),
            KkCrumb(code: 'SEC-04', cjk: '冷却', en: 'coolant', onPressed: () => log.add('coolant')),
          ],
        ),
        size: const Size(900, 300),
      );
      const KkColors c = KkColors.standby;
      expect(tester.widget<Text>(find.text('BOARD')).style!.color, c.signal);
      expect(tester.widget<Text>(find.text('系統')).style!.color, c.signal);
      expect(tester.widget<Text>(find.text('COOLANT')).style!.color, c.ink);
      expect(tester.widget<Text>(find.text('HQ-03')).style!.color, c.inkFaint);
      expect(tester.widget<Text>(find.text('BOARD')).style!.fontSize, 12);
      expect(tester.widget<Text>(find.text('系統')).style!.fontSize, 13);
      expect(find.text('/'), findsNWidgets(2));

      await tester.tap(find.text('BOARD'));
      await tester.tap(find.text('SYSTEMS'));
      await tester.tap(find.text('COOLANT'));
      expect(log, <String>['board', 'systems']);
    });

    testWidgets('a Latin-only trail is 18px high: 12px type with 3px above and below', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBreadcrumbs(
          items: <KkCrumb>[
            KkCrumb(en: 'board', onPressed: () {}),
            const KkCrumb(en: 'systems'),
          ],
        ),
      );
      expect(tester.getSize(find.byType(KkBreadcrumbs)).height, 18);
    });

    testWidgets('links take keyboard focus and Enter follows them', (WidgetTester tester) async {
      int hits = 0;
      await pumpKk(
        tester,
        KkBreadcrumbs(
          items: <KkCrumb>[
            KkCrumb(en: 'board', onPressed: () => hits++),
            const KkCrumb(en: 'here'),
          ],
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(hits, 1);
    });

    testWidgets('the trail wraps when it does not fit; a custom separator is used', (WidgetTester tester) async {
      await pumpKk(
        tester,
        KkBox(
          width: 140,
          child: KkBreadcrumbs(
            separator: const KkIcon(KkIcons.chevronRight, size: 10),
            items: <KkCrumb>[for (int i = 0; i < 6; i++) KkCrumb(en: 'sector $i', onPressed: () {})],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('/'), findsNothing);
      expect(find.byType(KkIcon), findsNWidgets(5));
      expect(tester.getSize(find.byType(KkBreadcrumbs)).height, greaterThan(40));
      await pumpKk(tester, const KkBreadcrumbs(items: <KkCrumb>[]));
      expect(tester.takeException(), isNull);
    });
  });
}
